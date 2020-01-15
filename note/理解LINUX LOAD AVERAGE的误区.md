# [理解LINUX LOAD AVERAGE的误区](http://linuxperf.com/?p=176)

uptime和top等命令都可以看到load average指标，从左至右三个数字分别表示1分钟、5分钟、15分钟的load average：

```shell
$ uptime
 10:16:25 up 3 days, 19:23,  2 users,  load average: 0.00, 0.01, 0.05
```

Load average的概念源自UNIX系统，虽然各家的公式不尽相同，但都是用于衡量正在使用CPU的进程数量和正在等待CPU的进程数量，一句话就是runnable processes的数量。所以load average可以作为CPU瓶颈的参考指标，如果大于CPU的数量，说明CPU可能不够用了。

但是，Linux上不是这样的！

Linux上的load average除了包括正在使用CPU的进程数量和正在等待CPU的进程数量之外，还包括uninterruptible sleep的进程数量。通常等待IO设备、等待网络的时候，进程会处于uninterruptible sleep状态。Linux设计者的逻辑是，uninterruptible sleep应该都是很短暂的，很快就会恢复运行，所以被等同于runnable。然而uninterruptible sleep即使再短暂也是sleep，何况现实世界中uninterruptible sleep未必很短暂，大量的、或长时间的uninterruptible sleep通常意味着IO设备遇到了瓶颈。众所周知，sleep状态的进程是不需要CPU的，即使所有的CPU都空闲，正在sleep的进程也是运行不了的，所以sleep进程的数量绝对不适合用作衡量CPU负载的指标，Linux把uninterruptible sleep进程算进load average的做法直接颠覆了load average的本来意义。所以在Linux系统上，load average这个指标基本失去了作用，因为你不知道它代表什么意思，当看到load average很高的时候，你不知道是runnable进程太多还是uninterruptible sleep进程太多，也就无法判断是CPU不够用还是IO设备有瓶颈。

参考资料：[https://en.wikipedia.org/wiki/Load_(computing)
](https://en.wikipedia.org/wiki/Load_(computing))“Most UNIX systems count only processes in the running (on CPU) or runnable (waiting for CPU) states. However, Linux also includes processes in uninterruptible sleep states (usually waiting for disk activity), which can lead to markedly different results if many processes remain blocked in I/O due to a busy or stalled I/O system.“[
](https://en.wikipedia.org/wiki/Load_(computing))

源代码：

```c
RHEL6
kernel/sched.c:
===============
 
static void calc_load_account_active(struct rq *this_rq)
{
        long nr_active, delta;
 
        nr_active = this_rq->nr_running;
        nr_active += (long) this_rq->nr_uninterruptible;
 
        if (nr_active != this_rq->calc_load_active) {
                delta = nr_active - this_rq->calc_load_active;
                this_rq->calc_load_active = nr_active;
                atomic_long_add(delta, &calc_load_tasks);
        }
}
```

```c
RHEL7
kernel/sched/core.c:
====================
 
static long calc_load_fold_active(struct rq *this_rq)
{
        long nr_active, delta = 0;
 
        nr_active = this_rq->nr_running;
        nr_active += (long) this_rq->nr_uninterruptible;
 
        if (nr_active != this_rq->calc_load_active) {
                delta = nr_active - this_rq->calc_load_active;
                this_rq->calc_load_active = nr_active;
        }
 
        return delta;
}
```

```c

2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
RHEL7
kernel/sched/core.c:
====================
 
/*
 * Global load-average calculations
 *
 * We take a distributed and async approach to calculating the global load-avg
 * in order to minimize overhead.
 *
 * The global load average is an exponentially decaying average of nr_running +
 * nr_uninterruptible.
 *
 * Once every LOAD_FREQ:
 *
 *   nr_active = 0;
 *   for_each_possible_cpu(cpu)
 *      nr_active += cpu_of(cpu)->nr_running + cpu_of(cpu)->nr_uninterruptible;
 *
 *   avenrun[n] = avenrun[0] * exp_n + nr_active * (1 - exp_n)
 *
 * Due to a number of reasons the above turns in the mess below:
 *
 *  - for_each_possible_cpu() is prohibitively expensive on machines with
 *    serious number of cpus, therefore we need to take a distributed approach
 *    to calculating nr_active.
 *
 *        \Sum_i x_i(t) = \Sum_i x_i(t) - x_i(t_0) | x_i(t_0) := 0
 *                      = \Sum_i { \Sum_j=1 x_i(t_j) - x_i(t_j-1) }
 *
 *    So assuming nr_active := 0 when we start out -- true per definition, we
 *    can simply take per-cpu deltas and fold those into a global accumulate
 *    to obtain the same result. See calc_load_fold_active().
 *
 *    Furthermore, in order to avoid synchronizing all per-cpu delta folding
 *    across the machine, we assume 10 ticks is sufficient time for every
 *    cpu to have completed this task.
 *
 *    This places an upper-bound on the IRQ-off latency of the machine. Then
 *    again, being late doesn't loose the delta, just wrecks the sample.
 *
 *  - cpu_rq()->nr_uninterruptible isn't accurately tracked per-cpu because
 *    this would add another cross-cpu cacheline miss and atomic operation
 *    to the wakeup path. Instead we increment on whatever cpu the task ran
 *    when it went into uninterruptible state and decrement on whatever cpu
 *    did the wakeup. This means that only the sum of nr_uninterruptible over
 *    all cpus yields the correct result.
 *
 *  This covers the NO_HZ=n code, for extra head-aches, see the comment below.
 */
```

