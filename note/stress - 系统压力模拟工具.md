## [stress - 系统压力模拟工具](https://pengrl.com/p/42434/)

### 前言

`stress`是一个故意制造系统压力的工具。它提供了一系列的参数用于配置如何制造CPU，内存，IO操作，磁盘压力。

### 安装

```
# centos平台
$yum install epel-release
$yum install stress
```

### 参数说明

```
-c, --cpu N
    spawn N workers spinning on sqrt()
    启动n个worker循环执行sqrt计算，用于模拟cpu型进程
-i, --io N
    spawn N workers spinning on sync()
    循环执行sync，模拟io型进程
-m, --vm N
    spawn N workers spinning on malloc()/free()
    循环调用malloc和free申请和释放内存
--vm-bytes B
    malloc B bytes per vm worker (default is 256MB)
    每次申请多大内存
--vm-stride B
    touch a byte every B bytes (default is 4096)
    每多少字节强制读写一个字节，避免空操作的申请释放被优化掉
--vm-hang N
    sleep N secs before free (default none, 0 is inf)
    申请多久后释放
--vm-keep
    redirty memory instead of freeing and reallocating
    只申请释放一次
-t, --timeout N
    timeout after N seconds
    执行多少秒后退出程序
.
.
.
```

`stress`中的worker都是通过多进程方式实现的，每个worker是一个独立子进程。

### 使用场景

#### 模拟多种场景举例

```
# 8个cpu类型进程，4个io类型进程，2个不停申请释放内存的进程，每次申请128M大小内存，10后退出stress程序
$stress --cpu 8 --io 4 --vm 2 --vm-bytes 128M --timeout 10s
```

#### 模拟cpu应用

```
# 开启1个cpu类型进程
$stress -c 1 -t 600
# 开启8个cpu类型进程
$stress -c 8 -t 600
```

#### 模拟io应用

```
$stress -i 1 -t 600
```

### 其他

#### 关于`-i`参数无法模拟io高的场景

这是因为strss是通过循环调用sync函数来模拟io高的场景。sync的作用是将所有的对文件的修改的缓冲写入文件系统。
然而如果系统对文件修改的缓冲本来就很少，那么就无法模拟io高的场景。
另外，由于是死循环调用sync这个系统调用的函数，所以可能会导致cpu sys升高。

sync函数说明： [sync(2): commit buffer cache to disk - Linux man page](https://linux.die.net/man/2/sync)

#### 关于实现

stress的代码量很小，只有一个760行的c文件，感兴趣或者对参数不理解可以直接看看代码。
在以下这个网页内有下载链接： [stress project page](https://people.seas.harvard.edu/~apw/stress/)

### 参考链接

- [stress(1): impose load on/stress test systems - Linux man page](https://linux.die.net/man/1/stress) (https://linux.die.net/man/1/stress)
- [Linux stress 命令 - sparkdev - 博客园](https://www.cnblogs.com/sparkdev/p/10354947.html) (https://www.cnblogs.com/sparkdev/p/10354947.html)

- *[Linux 压力测试软件 Stress 使用指南 - 运维之美](https://www.hi-linux.com/posts/59095.html)* (https://www.hi-linux.com/posts/59095.html)
- *[系统技术非业余研究 - 给你的Linux系统上点stress](http://blog.yufeng.info/archives/2023)* (http://blog.yufeng.info/archives/2023)
- *[Linux压力测试工具stress的参数详解 - 51CTO.COM](http://os.51cto.com/art/201507/485967.htm)* (http://os.51cto.com/art/201507/485967.htm)