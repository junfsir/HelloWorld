# [一次 JBD2进程导致磁盘 IO 高的分析解决过程](https://www.easyice.cn/archives/328)

## 故障现象

在3节点组成的大数据集群中，混部了 ES，kafka，zk，pg，mysql，spark，yarn，hdfs，以及业务的 etl 程序等组件。起初发现业务进程处理数据速度很慢，排查后发现数据盘 /data01 的 util 接近100%

![img](https://www.easyice.cn/archives/media/15682854550251/15682860695927.jpg)

但是磁盘吞吐量并不高，IO 流量只有2MB 左右，主要是由 w/s 导致，也就是写入的 iops 高，这种情况一般就是进程的 sync 操作密集。

## 分析过程

通过 iotop 来查看是哪个进程，显示为 jbd2

![img](https://www.easyice.cn/archives/media/15682854550251/15682858775788.jpg)

查阅一些资料后，了解到 jbd2进程负责 ext4这种日志文件系统的日志提交操作，关于jbd2引起磁盘 io 高，网上也有很多类似案例，总结起来有几方面原因：

1. 系统 bug
2. ext4文件系统的相关配置问题
3. 其他进程的 fsync，sync 操作过于频繁

首先排除系统 bug因素，网络上反馈的问题在很低的版本，我们生产环境为 Centos 7.4，其次，查阅了 /proc/mounts 等信息，发现文件系统配置参数与其他环境差异不大，按照网上提供的关闭某些特性，降低 commit 频率等理论来说会有效果，但需要重新 mount 磁盘，相关组件都要重启，并且这看起来并非根本原因。

尝试分析 sync 调用，使用 sysdig 最方便，但现场环境安装很麻烦，因此开启几个内核 trace查看：

在 jbd2执行 flush 时输出日志

```shell
echo 1 > /sys/kernel/debug/tracing/events/jbd2/jbd2_commit_flushing/enable
```

在任意进程执行 sync 时输出日志

```shell
echo 1 > /sys/kernel/debug/tracing/events/ext4/ext4_sync_file_enter/enable
```

然后观察日志输出：

```shell
cat /sys/kernel/debug/tracing/trace_pipe
```

输出信息如下：

![img](https://www.easyice.cn/archives/media/15682854550251/15682868612383.jpg)

可以看到 jbd2和 java-17417进程有大量的 sync，瞬间刷出大量日志，因此基本确定 java-17417进程。17417为 java 进程的 tid，ps 看一下是哪个任务导致的：

```shell
ps -efL |grep 17417
```

-L 或-T 参数显示线程 id，ps 获取到 pid 和程序路径后，发现是 zk 进程，很让人疑惑，zk 怎么会大量 sync 呢，trace 一下他在做什么：

```shell
strace -f -p 17417
```

输出信息如下：

![img](https://www.easyice.cn/archives/media/15682854550251/15682871075288.jpg)

根据 fd 号去看看这是什么文件：

```shell
ll /proc/{zk_pid}/fd/74
```

发现是 log.xxx，是 zk 的事务日志，zk 频繁写事务日志，是由于对 zk 执行了大量写操作导致的。为了确认是 zk 引起的问题，将 zk 的数据路径修改到其他盘，重启 zk 节点，发现变成其他盘的 util 跑满了，到此为止确认是 zk 引起的。

## 解决方式

经过与业务沟通后，确认是业务进程设计不合理，对 zk 执行大量写操作，暂时采取临时措施，将 zk 的数据路径调整到系统盘，系统盘为 ssd