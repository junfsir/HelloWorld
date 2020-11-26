一天时间内，2个kubernetes节点在短时间内出现hung住不响应的情况，日志如下：

```shell
INFO: task jbd2/vda1-8:2109 blocked for more than 120 seconds.
      Not tainted 4.4.186-1.el7.elrepo.x86_64 #1
"echo 0 > /proc/sys/kernel/hung_task_timeout_secs" disables this message.
jbd2/vda1-8     D ffff8800360c39e8     0  2109      2 0x00000000
 ffff8800360c39e8 ffff880429908000 ffff88042c0d9d80 ffff8800360c4000
 0000000000000000 7fffffffffffffff ffff88043ff99fb0 ffffffff8171cb70
 ffff8800360c3a00 ffffffff8171c2f5 ffff88042fc17240 ffff8800360c3aa8
```

默认情况下，Linux内核会设置40%的可用内存用来做系统cache。当超过这个阈值后，内核会把缓存中脏数据全部flush到磁盘，导致后续的IO请求都是同步的。在写入磁盘时，默认120s超时，出现上述问题就是数据写入磁盘时间超出120s。flush数据时，IO系统响应缓慢，导致IO请求堆积，最终导致系统内存被全部占用，失去响应。

可调整以下参数来避免这个问题

```shell
# sysctl -w vm.dirty_ratio=10
# sysctl -w vm.dirty_background_ratio=5
# sysctl -p
```



[Linux Kernel panic issue: How to fix hung_task_timeout_secs and blocked for more than 120 seconds problem](https://www.blackmoreops.com/2014/09/22/linux-kernel-panic-issue-fix-hung_task_timeout_secs-blocked-120-seconds-problem/)

