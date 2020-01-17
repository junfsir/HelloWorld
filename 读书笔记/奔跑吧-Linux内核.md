## 第一章 处理器结构体系

### 精简指令集RISC和复杂指令集CISC

20世纪70年代，IBM的John Cocke研究发现，处理器提供的大量指令集和复杂寻址方式并不会被编译器生成的代码用到：20%的简单指令经常被用到，占程序总指令数的80%，而指令集里其余80%的复杂指令很少被用到，只占程序总指令数的20%。基于这种思想，将指令集和处理器进行重新设计，在新的设计中只保留了常用的简单指令，这样处理器不需要浪费太多的晶体管去做那些很复杂又很少使用的复杂指令。通常，简单指令大部分时间都能在一个cycle内完成，基于这种思想的指令集叫作RISC（Reduced Instruction Set Computer）指令集，以前的指令集叫作CISC（Complex Instruction Set Computer）指令集。







## 第六章 内核调试

### ftrace

ftrace最早出现在Linux 2.6.27版本中，其设计目标简单，基于静态代码插装技术，不需要用户通过额外的编程来定义trace行为。静态代码插装技术比较可靠，不会因为用户的不当使用而导致内核崩溃。ftrace的名字由function trace而来，利用gcc编译器的profile特性在所有函数入口处添加了一段插桩（stub）代码，ftrace重载这段代码来实现trace功能。gcc编译器的“-pg”选项会在每个函数入口处加入mcount的调用代码，原本mcount有libc实现，因为内核不会链接libc库，因此ftrace编写了自己的mcount stub函数。

在使用ftrace之前，需要确保内核编译了其配置选项：

```shell
# cat  /usr/src/kernels/$(uname -r)/.config
    CONFIG_FUNCTION_TRACER
    CONFIG_FUNCTION_GRAPH_TRACER
    CONFIG_STACK_TRACER
    CONFIG_DYNAMIC_FTRACE
```

ftrace通过debugfs文件系统向用户空间提供访问接口，因此需要在系统启动时挂载debugfs，可以修改系统的/etc/fstab文件或手工挂载。

```shell
# mount -t debugfs debugfs /sys/kernel/debug
```

在/sys/kernel/debug/tracing目录下提供了各种跟踪器（tracer）和event事件，一些常用的选项如下：

- [ ] available_tracers：列出当前系统支持的跟踪器；
- [ ] available_events：列出当前系统支持的event事件；
- [ ] current_tracer：设置和显示当前正在使用的跟踪器。使用echo命令可以把跟踪器的名字写入该文件，即可以切换不同的跟踪器。默认为nop，即不做任何跟踪操作；
- [ ] trace：读取跟踪信息。通过cat命令查看ftrace记录下来的跟踪信息；
- [ ] tracing_on：用于开始或暂停跟踪；
- [ ] trace_options：设置ftrace的一些相关选项；

ftrace当前包含多个跟踪器，很方便用户用来跟踪不同类型的信息，例如进程睡眠唤醒、抢占延迟的信息。查看available_tracers可以知道当前系统支持哪些跟踪器，如果系统支持的跟踪器上没有用户想要的，那就必须在配置内核时自行打开，然后重新编译内核。常用的ftrace跟踪器如下：

- [ ] nop：不跟踪任何信息。将nop写入current_tracer文件可以清空之前收集到的跟踪信息；
- [ ] function：跟踪内核函数执行情况；
- [ ] function_graph：可以显示类似C语言的函数调用关系图，比较直观；
- [ ] wakeup：跟踪进程唤醒信息；
- [ ] irqsoff：跟踪关闭中断信息，并记录关闭的最大时长；
- [ ] preemptoff：跟踪关闭禁止抢占信息，并记录关闭的最大时长；
- [ ] preemptirqsoff：综合了irqoff和preemptoff两个功能；
- [ ] sched_switch：对内核中的进程调度活动进行跟踪；



