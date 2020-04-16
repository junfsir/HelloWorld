今天遇到了传说中的`PLEG is not healthy`，在业务升级过程中，一节点的`pod`一直处于`Terminating`中，看节点的`kubelet`日志显示`PLEG: pod xxx failed reinspection: rpc error: code = DeadlineExceeded desc = context deadline exceeded`，节点状态在`Ready`和`NotReady`之前切换，从`docker`和`kubelet`日志来看，是`kubelet`一直在让`docker kill`一个容器，但是`failed to exit within 30 seconds of signal 15 - using the force`，就一直处在循环状态。

处理过程如下：

首先根据日志中的`pod`找到具体的容器，发现`pause`容器早就退出了，但是业务容器还在运行：

```shell
# docker ps -a |grep xxx
c261ef216d40        e4a981403445                                                                    "bash /data/thanos/b…"   4 months ago        Up 4 months                                     xxxx
e3af9f2e3010        k8s.gcr.io/pause:3.1                                                            "/pause"                 4 months ago        Exited (0) 20 minutes ago                         xxxx
```

尝试使用`docker rm`来删除容器，也一直卡住；

所以看下`runc`的状态（根据`containerid`来找下`runc`进程）：

```shell
# ps aux|grep c261ef216d40
root     24978  0.0  0.0  71324 63640 ?        Sl    2019  97:02 docker-containerd-shim -namespace moby -workdir /data/docker/containerd/daemon/io.containerd.runtime.v1.linux/moby/c261ef216d409399305897eeaf83eea1afcb05259537c903774a82d7b9893fcb -address /var/run/docker/containerd/docker-containerd.sock -containerd-binary /usr/bin/docker-containerd -runtime-root /var/run/docker/runtime-runc
```

看下这个进程的子进程的状态，发现处于僵尸状态：

```shell
# ps -ef|grep 24978
root     30260 24978  0 4月15 ?       00:00:00 [docker-containe] <defunct>
root     30261 24978  0 4月15 ?       00:00:00 [docker-runc] <defunct>
```

然后杀掉该容器的`runc`进程后，`kubelet`恢复正常；

> Docker容器拒绝在运行命令变成僵尸后被杀死(Docker container refuses to get killed after run command turns into a zombie)