# [OOM分析](https://cloud.tencent.com/developer/article/1157275)

oom_killer（out of memory killer）是Linux内核的一种内存管理机制，在系统可用内存较少的情况下，内核为保证系统还能够继续运行下去，会选择杀掉一些进程释放掉一些内存。通常oom_killer的触发流程是：`进程A想要分配物理内存（通常是当进程真正去读写一块内核已经“分配”给它的内存）->触发缺页异常->内核去分配物理内存->物理内存不够了，触发OOM`。

## 一句话说明oom_killer的功能：

```js
当系统物理内存不足时，oom_killer遍历当前所有进程，根据进程的内存使用情况进行打分，然后从中选择一个分数最高的进程，杀之取内存。
```

## 函数解析：

oom_killer的处理主要集中在`mm/oom_kill.c`。

核心函数为out_of_memory，函数处理流程：

1. 通知系统中注册了oom_notify_list的模块释放一些内存，如果从这些模块中释放出了一些内存，那么皆大欢喜，直接结束oom killer流程，回收失败, 那只有进入下一步开始oom_killer了；
2. 触发oom killer通常是由当前进程进行内存分配所引起，而如果当前进程已经挂起了一个SIG_KILL信号，直接选中当前进程，否则进入下一步；
3. check_panic_on_oom检查系统管理员的态度，看oom时是进行oom killer还是直接panic掉，如果进行oom killer，则进入下一步；
4. 如果系统管理员规定，谁引起oom，杀掉谁，那就杀掉正在尝试分配内存的进程，oom killer结束，否则进入下一步；
5. 调用select_bad_process选中合适进程，然后调用oom_kill_process杀死选中进程，如果不幸select_bad_process没有选出任何进程，那么内核走投无路，只有panic了。

### 主函数out_of_memory

```js
void out_of_memory(struct zonelist *zonelist, gfp_t gfp_mask,

  int order, nodemask_t *nodemask)

{

 const nodemask_t *mpol_mask;

 struct task_struct *p;

 unsigned long totalpages;

 unsigned long freed = 0;

 unsigned int points;

 enum oom_constraint constraint = CONSTRAINT_NONE;

 int killed = 0;



 /*

 通知注册在oom_notify_list上的模块，释放一些内存出来，如果成功，那就不用启动oom killer了

 */

 blocking_notifier_call_chain(&oom_notify_list, 0, &freed);

 if (freed > 0)

  /* Got some memory back in the last second. */

  return;



  /*

  如果当前想要分配内存的进程恰好有一个pending的SIGKILL信号，那么OK，不用费事了，当前进程被光荣选中，直接返回给它时间去处理信号即可

  */

 if (fatal_signal_pending(current)) {

  set_thread_flag(TIF_MEMDIE);

  return;

 }



 /*对于有NUMA节点，会有节点间的限制*/

 constraint = constrained_alloc(zonelist, gfp_mask, nodemask,

      &totalpages);

 mpol_mask = (constraint == CONSTRAINT_MEMORY_POLICY) ? nodemask : NULL;



 /*

 检查/proc/sys/vm/panic_on_oom的设置，看看系统管理员是什么态度

 */

 check_panic_on_oom(constraint, gfp_mask, order, mpol_mask); 



 read_lock(&tasklist_lock);

 /*

 /proc/sys/vm/oom_kill_allocating_task为true的时候，直接kill掉当前想要分配内存的进程(此进程能够被kill时)

 */

 if (sysctl_oom_kill_allocating_task && 

     !oom_unkillable_task(current, NULL, nodemask) &&

     current->mm && !atomic_read(&current->mm->oom_disable_count)) {

  if (!oom_kill_process(current, gfp_mask, order, 0, totalpages,

    NULL, nodemask,

    "Out of memory (oom_kill_allocating_task)"))

   goto out;

 }



    /*执行到此处，内核开始对所有进程进行审判，择其最坏者杀之*/

retry:

 /*

 选择一个最适合被杀死的进程

 */

 p = select_bad_process(&points, totalpages, NULL, mpol_mask);

 if (PTR_ERR(p) == -1UL)/*上次oom killer选择杀死的进程还正在结束中，或者有一些进程正在结束中，那退出本次oom的处理，等待其它进程结束，防止不必要的进程kill动作*/

  goto out;



 /* 找了一圈，没有找到任何一个进程可以被杀死（全都是背景深厚的进程…），内核走投无路，自杀*/

 if (!p) {

  dump_header(NULL, gfp_mask, order, NULL, mpol_mask);

  read_unlock(&tasklist_lock);

  panic("Out of memory and no killable processes...\n");

 }



     /*幸运的找到了一个合适的进程，去kill它，释放一点内存出来*/

 if (oom_kill_process(p, gfp_mask, order, points, totalpages, NULL,

    nodemask, "Out of memory"))

  goto retry;

 killed = 1;

out:

 read_unlock(&tasklist_lock);



  /*

 如果有进程被选中了kill掉，且又不是当前进程，那主动让出CPU，给被选中

 的进程一些时间去处理后事，结束它自己的生命

 */

 if (killed && !test_thread_flag(TIF_MEMDIE))

  schedule_timeout_uninterruptible(1);/*主动让出cpu*/

}
```

### 其它相关函数说明：

（1）check_panic_on_oom

check_panic_on_oom会对”/proc/sys/vm/panic_on_oom”值进行检查：

- 0：不产生panic，启动 oom_killer 功能
- 2：发生oom时强制产生panic
- 其它值：将检查下是否为Cgroup、NUMA等约束引起的，如果是就开启oom_killer，否则产生panic

```js
static void check_panic_on_oom(enum oom_constraint constraint, gfp_t gfp_mask,

    int order, const nodemask_t *nodemask)

{

 if (likely(!sysctl_panic_on_oom))	//0表示启动OOM killer，因此直接return了 

  return;

 if (sysctl_panic_on_oom != 2) {	//2是强制panic，不是2的话，还可以商量 

  if (constraint != CONSTRAINT_NONE)	//在有cpuset、memory policy、memcg的约束情况下的OOM，可以考虑不panic，而是启动OOM killer 

   return;

 }

 read_lock(&tasklist_lock);

 dump_header(NULL, gfp_mask, order, NULL, nodemask);

 read_unlock(&tasklist_lock);

 panic("Out of memory: %s panic_on_oom is enabled\n",

 sysctl_panic_on_oom == 2 ? "compulsory" : "system-wide");	//OK，产生panic，死给你们看

}
```

（2）select_bad_process

slect_bad_process从系统中选择一个适合被杀死的进程，对于系统关键进程（如init进程、内核线程等）是不能被杀死的，其它进程则通过oom_badness进行打分（0~1000），分数最高者被选中 

```js
static struct task_struct *select_bad_process(unsigned int *ppoints,

  unsigned long totalpages, struct mem_cgroup *mem,

  const nodemask_t *nodemask)

{

 struct task_struct *g, *p;

 struct task_struct *chosen = NULL;

 *ppoints = 0;



 /*从init_task开始遍历所有进程，选择最应该被杀的进程*/

 do_each_thread(g, p) {

  unsigned int points;



  /*进程已经退出就不管了*/

  if (p->exit_state) 

   continue;

  /*核心进程不能杀(init、内核线程等)*/

  if (oom_unkillable_task(p, mem, nodemask))

   continue;

  /*已经有一个进程被oom killer选中,并正在被杀死(上一次触发的oom还没有处理完)，结束本次的oom killer*/

  if (test_tsk_thread_flag(p, TIF_MEMDIE))

   return ERR_PTR(-1UL);

  if (!p->mm)

   continue;



  /*进程整处于结束阶段*/

  if (p->flags & PF_EXITING) {

   if (p == current) {

    chosen = p;

    *ppoints = 1000;

   } else {

    if (!(task_ptrace(p->group_leader) &

       PT_TRACE_EXIT))

     return ERR_PTR(-1UL);

   }

  }



  /*根据进程对物理内存(以及swap分区使用情况)给进程打分*/

  points = oom_badness(p, mem, nodemask, totalpages);

  if (points > *ppoints) {

   chosen = p;

   *ppoints = points;

  }

 } while_each_thread(g, p);



 return chosen; //如果一个没选中(比如所有进程都被设置了保护)，那就只有悲伤的返回NULL了

}
```

（3）oom_badness

oom_badness给进程打分，系统管理员可以通过`/proc/<PID>/oom_score_adj`或`/proc/<PID>/oom_adj`影响oom killer对进程的打分，子进程也会继承该权值：

- /proc/<PID>/oom_adj：（-17~15）
- 取值范围：-16~15，值越小进程越不容易被选中
- 禁止oom killer选中PID进程：-17
- /proc/<PID>/oom_score_adj：（-1000~1000）
- 取值范围：-999~1000:，值越小进程越不容易被选中
- 禁止oom killer选中PID进程：-1000

**注意：**

内核中已经废弃了oom_adj的使用，现在oom计分是依赖于oom_score_adj，因此系统管理时建议设置/proc/<PID>/oom_score_adj，内核依然保持oom_adj设置以兼容旧版本，系统中对oom_score_adj或oom_adj中任一个进行设置，内核中都会进行两者之间的相互转换，转换关系如下：

- 2.6（Centos6）

```js
oom_score_adj=(oom_adj*1000)/17

oom_adj= (oom_score_adj*15)/1000    

当设置oom_adj=-16时，oom_score_adj自动调整为-941

当设置oom_score_adj=-950时，oom_adj自动调整为-14
```

- 3.10（Centos7）

```js
oom_score_adj= (oom_adj*1000)/17

oom_adj=(oom_score_adj*17)/1000

当设置oom_adj=-16时，oom_score_adj自动调整为-941

当设置oom_score_adj=-950时，oom_adj自动调整为-16
```

oom_badness函数

```js
/*内核选择最坏的进程(根据其内存使用情况打分决定)

 返回分值:0~1000,分数越低越安全，分数为0的进程不会被杀掉*/

unsigned int oom_badness(struct task_struct *p, struct mem_cgroup *mem,

        const nodemask_t *nodemask, unsigned long totalpages)

{

 long points;



 if (oom_unkillable_task(p, mem, nodemask))	//背景深厚杀不得的进程

  return 0;



 p = find_lock_task_mm(p);

 if (!p)

  return 0;





  /*oom_score_adj为-1000(或者oom_adj为-17)的不做处理，

  此值可以通过/proc/pid_num/oom_score_adj(oom_adj)设置, 

  */

 if (atomic_read(&p->mm->oom_disable_count)) {

  task_unlock(p);

  return 0;

 }



 /*

  * The memory controller may have a limit of 0 bytes, so avoid a divide

  * by zero, if necessary.

  */

 if (!totalpages)

  totalpages = 1;

  /*

  获取进程的rss(用户空间的文件映射和匿名页占用的物理内存页数)、页表和swap中使用内存空间的情况

  */

 points = get_mm_rss(p->mm) + p->mm->nr_ptes;

 points += get_mm_counter(p->mm, swap_usage);



 points *= 1000;

 points /= totalpages;

 task_unlock(p);



  /*如果进程拥有CAP_SYS_ADMIN能力，得分减少30，通常具有CAP_SYS_ADMIN的进程是被当做表现良好，

  一般不会出现内存泄露的进程*/

 if (has_capability_noaudit(p, CAP_SYS_ADMIN))

  points -= 30;



  /*加上oom_score_adj的值，该值通过/proc/<PID>/oom_score_adj进行设置，有效范围-1000~1000*/

 points += p->signal->oom_score_adj;



  /*返回分值1~1000，分值越高越容易被oom选中kill掉*/

 if (points <= 0)

  return 1;

 return (points < 1000) ? points : 1000;

}
```

（4）oom_kill_process

```js
/*

返回值0表示成功kill掉了一个最坏的进程，非0的返回表示发生了一些错误

*/

static int oom_kill_process(struct task_struct *p, gfp_t gfp_mask, int order,

       unsigned int points, unsigned long totalpages,

       struct mem_cgroup *mem, nodemask_t *nodemask,

       const char *message)

{

 struct task_struct *victim = p;

 struct task_struct *child;

 struct task_struct *t = p;

 unsigned int victim_points = 0;



 if (printk_ratelimit())

  dump_header(p, gfp_mask, order, mem, nodemask); //打印内核进程等的状态信息



 if (p->flags & PF_EXITING) {	//进程正在结束中

  set_tsk_thread_flag(p, TIF_MEMDIE);

  return 0;

 }



 task_lock(p);

 pr_err("%s: Kill process %d (%s) score %d or sacrifice child\n",

  message, task_pid_nr(p), p->comm, points);

 task_unlock(p);



  /*

  如果选中被杀的进程拥有子进程(有儿子)，且子进程与父进程的mm不一样(即地址

  空间不一样，好吧，分家了),那么从子进程中选择一个得分最高的进程代替父进程被

  杀掉(父债子偿)

  */

 do {

  list_for_each_entry(child, &t->children, sibling) {

   unsigned int child_points;



   if (child->mm == p->mm)

    continue;

   /*

    * oom_badness() returns 0 if the thread is unkillable

    */

   child_points = oom_badness(child, mem, nodemask,

        totalpages);

   if (child_points > victim_points) {

    victim = child;

    victim_points = child_points;

   }

  }

 } while_each_thread(p, t);



 return oom_kill_task(victim);

}





static int oom_kill_task(struct task_struct *p)

{

 struct task_struct *q;

 struct mm_struct *mm;



 p = find_lock_task_mm(p);

 if (!p)

  return 1;



 /*

 通过/proc/sys/vm/would_have_oomkilled进行设置，如果此处为true，则只是打印出一条消息，并不会kill掉进程，并且返回成功(有些费解，都到这一步了，还留之做甚，就是为了给管理员警告下?)

 */

 if (sysctl_would_have_oomkilled == 1) {

  printk(KERN_ERR "Would have killed process %d (%s). But continuing instead.\n",

    task_pid_nr(p), p->comm);

  task_unlock(p);

  return 0;

 }



 /* mm cannot be safely dereferenced after task_unlock(p) */

 mm = p->mm;



 pr_err("Killed process %d, UID %d, (%s) total-vm:%lukB, anon-rss:%lukB, file-rss:%lukB\n",

  task_pid_nr(p), task_uid(p), p->comm, K(p->mm->total_vm),

  K(get_mm_counter(p->mm, anon_rss)),

  K(get_mm_counter(p->mm, file_rss)));

 task_unlock(p);



 /*

 对于所有与被选中进程共享地址空间的进程，都要被杀掉(共享其利，共承其责)

 */

 for_each_process(q)

  if (q->mm == mm && !same_thread_group(q, p)) {

   task_lock(q);	/* Protect ->comm from prctl() */

   pr_err("Kill process %d (%s) sharing same memory\n",

    task_pid_nr(q), q->comm);

   task_unlock(q);

   force_sig(SIGKILL, q);	//向进程传递SIGKILL信号

  }

 

 set_tsk_thread_flag(p, TIF_MEMDIE);	//标记该进程已经被oom_killer选中，正在被kill

 force_sig(SIGKILL, p);



 return 0;

}
```

# 系统相关配置

- /proc/sys/vm/panic_on_oom：配置系统产生oom时的动作
- /proc/sys/vm/oom_kill_allocating_task：为true的时候，直接kill掉当前想要分配内存的进程(此进程能够被kill时)
- /proc/<pid>/oom_score_adj（或/proc/<pid>/oom_adj）：配置PID指定进程的oom权重，子进程继承该权重值
- /proc/sys/vm/would_have_oomkilled：为true时并不会真正杀死oom killer选中进程，只是打印一条警告信息
- echo f >/proc/sysrq-trigger模拟oom
- cat /proc/<PID>/oom_score：查看PID进程的oom分数