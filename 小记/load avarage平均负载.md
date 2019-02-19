## load avarage的定义：
*在特定时间间隔内，运行队列中的平均进程数。通俗一点来说，就是单位时间内cpu等待运行的进程个数。*
### 一个进程满足什么条件才算位于运行队列中：

- 该进程没有在等待IO结果；
- 该进程没有主动进入等待状态(即没有调用'wait')；
- 该进程没有被停止；

### 怎么查看平均负载

    ]# w
     09:21:25 up 12 days, 11:59,  1 user,  load average: 1.15, 1.20, 1.14
    USER     TTY      FROM              LOGIN@   IDLE   JCPU   PCPU WHAT
    root     pts/0    192.168.216.36   09:21    0.00s  0.01s  0.00s w

    ]# uptime
     09:22:31 up 12 days, 12:00,  1 user,  load average: 0.78, 1.08, 1.10

    ]# top
    top - 09:23:09 up 12 days, 12:01,  1 user,  load average: 1.10, 1.13, 1.12

### 怎么根据load avarage判断当前系统的负载状况
*命令输出的最后内容表示在过去的1、5、15分钟内运行队列中的平均进程数量。一般来说只要每个CPU的当前活动进程数不大于3那么系统的性能就是良好的，如果每个CPU的任务数大于5，那么就表示这台机器的性能有严重问题。对 于上面的例子来说，假设系统有两个CPU，那么其每个CPU的当前任务数为：8.13/2=4.065。这表示该系统的性能是可以接受的。*

[参考](http://www.ruanyifeng.com/blog/2011/07/linux_load_average_explained.html)

[top command](https://www.lifewire.com/linux-top-command-2201163)

[用户空间和内核空间](http://www.ruanyifeng.com/blog/2016/12/user_space_vs_kernel_space.html)







    Linux上的load average除了包括正在使用CPU的进程数量和正在等待CPU的进程数量之外，还包括uninterruptible sleep的进程数量。通常等待IO设备、等待网络的时候，进程会处于uninterruptible sleep状态。Linux设计者的逻辑是，uninterruptible sleep应该都是很短暂的，很快就会恢复运行，所以被等同于runnable。然而uninterruptible sleep即使再短暂也是sleep，何况现实世界中uninterruptible sleep未必很短暂，大量的、或长时间的uninterruptible sleep通常意味着IO设备遇到了瓶颈。众所周知，sleep状态的进程是不需要CPU的，即使所有的CPU都空闲，正在sleep的进程也是运行不了的，所以sleep进程的数量绝对不适合用作衡量CPU负载的指标，Linux把uninterruptible sleep进程算进load average的做法直接颠覆了load average的本来意义。所以在Linux系统上，load average这个指标基本失去了作用，因为你不知道它代表什么意思，当看到load average很高的时候，你不知道是runnable进程太多还是uninterruptible sleep进程太多，也就无法判断是CPU不够用还是IO设备有瓶颈。
    

*如何定位当前负载进程个数？*

    1.ps命令中状态为R的进程；
    2.vmstat r队列个数；
    3.top命令。