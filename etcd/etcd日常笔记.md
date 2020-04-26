**健康检查**

```shell
# curl -L http://127.0.0.1:2379/health
```

**wal日志**

wal日志是二进制的，解析出来后是以上数据结构LogEntry；其中第一个字段type，只有两种，一种是0表示Normal，1表示ConfChange（ConfChange表示 Etcd 本身的配置变更同步，比如有新的节点加入等）；第二个字段是term，每个term代表一个主节点的任期，每次主节点变更term就会变化；第三个字段是index，这个序号是严格有序递增的，代表变更序号；第四个字段是二进制的data，将raft request对象的pb结构整个保存下；Etcd 源码下有个tools/etcd-dump-logs，可以将wal日志dump成文本查看，可以协助分析raft协议；

raft协议本身不关心应用数据，也就是data中的部分，一致性都通过同步wal日志来实现，每个节点将从主节点收到的data apply到本地的存储，raft只关心日志的同步状态，如果本地存储实现的有bug，比如没有正确的将data apply到本地，也可能会导致数据不一致；

### etcd管理

```shell
1. 查看节点状态：
# curl 'http://10.204.0.22:2379/v2/members'
# ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 member list
2. 更新节点：
在本例中，我们假设要更新 ID 为 a8266ecf031671f3 的节点的 peerURLs 为：http://10.0.1.10:2380
# etcdctl member update a8266ecf031671f3 http://10.0.1.10:2380
Updated member with ID a8266ecf031671f3 in cluster
3. 删除一个节点：
假设我们要删除 ID 为 a8266ecf031671f3 的节点
# etcdctl member remove a8266ecf031671f3
Removed member a8266ecf031671f3 from cluster
执行完后，目标节点会自动停止服务，并且打印一行日志：
etcd: this member has been permanently removed from the cluster. Exiting.
如果删除的是 leader 节点，则需要耗费额外的时间重新选举 leader；
4. 增加一个新的节点
增加一个新的节点分为两步：
通过 etcdctl 或对应的 API 注册新节点；
使用恰当的参数启动新节点；
a. 先看第一步，假设我们要新加的节点取名为 infra3, peerURLs 是 http://10.0.1.13:2380；
# etcdctl member add infra3 http://10.0.1.13:2380
added member 9bf1b35fc7761a23 to cluster
ETCD_NAME="infra3"
ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
ETCD_INITIAL_CLUSTER_STATE=existing
b. etcdctl 在注册完新节点后，会返回一段提示，包含3个环境变量。然后在第二部启动新节点的时候，带上这3个环境变量即可；
# export ETCD_NAME="infra3"
# export ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
# export ETCD_INITIAL_CLUSTER_STATE=existing
# etcd -listen-client-urls http://10.0.1.13:2379 -advertise-client-urls http://10.0.1.13:2379  -listen-peer-urls http://10.0.1.13:2380 -initial-advertise-peer-urls http://10.0.1.13:2380 -data-dir %data_dir%
```

### Refer

https://k8smeetup.github.io/docs/getting-started-guides/ubuntu/backups/

https://skyao.gitbooks.io/learning-etcd3/content/documentation/op-guide/

https://github.com/coreos/etcd/blob/master/Documentation/op-guide/security.md

https://www.infoq.cn/article/etcd-interpretation-application-scenario-implement-principle

http://jolestar.com/etcd-architecture/

## 检查etcd服务运行状态

使用curl访问：

```shell
# curl http://10.10.0.14:2379/v2/members
```

返回以下结果为正常（3个节点）：

```json
{
  "members": [
    {
      "id": "1f890e0c67371d24",
      "name": "niub1",
      "peerURLs": [
        "http://niub-etcd-1:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-1:2379"
      ]
    },
    {
      "id": "b952ccccefdd8a93",
      "name": "niub3",
      "peerURLs": [
        "http://niub-etcd-3:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-3:2379"
      ]
    },
    {
      "id": "d6dbdb24d5bfc20f",
      "name": "niub2",
      "peerURLs": [
        "http://niub-etcd-2:2380"
      ],
      "clientURLs": [
        "http://niub-etcd-2:2379"
      ]
    }
  ]
}
```

## etcd备份

使用etcd自带命令`etcdctl`进行etc备份，脚本如下：

```shell
#!/bin/bash

date_time=`date +%Y%m%d`
etcdctl backup --data-dir /usr/local/etcd/niub3.etcd/ --backup-dir /niub/etcd_backup/${date_time}

find /niub/etcd_backup/ -ctime +7 -exec rm -r {} \;
```

## etcdctl操作

####  更新一个节点

如果你想更新一个节点的 IP(peerURLS)，首先你需要知道那个节点的 ID。你可以列出所有节点，找出对应节点的 ID。

```
$ etcdctl member list
6e3bd23ae5f1eae0: name=node2 peerURLs=http://localhost:23802 clientURLs=http://127.0.0.1:23792
924e2e83e93f2560: name=node3 peerURLs=http://localhost:23803 clientURLs=http://127.0.0.1:23793
a8266ecf031671f3: name=node1 peerURLs=http://localhost:23801 clientURLs=http://127.0.0.1:23791
```

在本例中，我们假设要更新 ID 为 `a8266ecf031671f3` 的节点的 peerURLs 为：`http://10.0.1.10:2380`

```
$ etcdctl member update a8266ecf031671f3 http://10.0.1.10:2380
Updated member with ID a8266ecf031671f3 in cluster
```

#### 删除一个节点

假设我们要删除 ID 为 `a8266ecf031671f3` 的节点

```
$ etcdctl member remove a8266ecf031671f3
Removed member a8266ecf031671f3 from cluster
```

执行完后，目标节点会自动停止服务，并且打印一行日志：

```
etcd: this member has been permanently removed from the cluster. Exiting.
```

如果删除的是 `leader` 节点，则需要耗费额外的时间重新选举 `leader`。

#### 增加一个新的节点

增加一个新的节点分为两步：

- 通过 `etcdctl` 或对应的 API 注册新节点
- 使用恰当的参数启动新节点

先看第一步，假设我们要新加的节点取名为 infra3, `peerURLs` 是 [http://10.0.1.13](http://10.0.1.13/):2380

```
$ etcdctl member add infra3 http://10.0.1.13:2380
added member 9bf1b35fc7761a23 to cluster

ETCD_NAME="infra3"
ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
ETCD_INITIAL_CLUSTER_STATE=existing
```

`etcdctl` 在注册完新节点后，会返回一段提示，包含3个环境变量。然后在第二步启动新节点的时候，带上这3个环境变量即可。

```
$ export ETCD_NAME="infra3"
$ export ETCD_INITIAL_CLUSTER="infra0=http://10.0.1.10:2380,infra1=http://10.0.1.11:2380,infra2=http://10.0.1.12:2380,infra3=http://10.0.1.13:2380"
$ export ETCD_INITIAL_CLUSTER_STATE=existing
$ etcd -listen-client-urls http://10.0.1.13:2379 -advertise-client-urls http://10.0.1.13:2379  -listen-peer-urls http://10.0.1.13:2380 -initial-advertise-peer-urls http://10.0.1.13:2380 -data-dir %data_dir%
```

这样，新节点就会运行起来并且加入到已有的集群中了。

值得注意的是，如果原先的集群只有1个节点，在新节点成功启动之前，新集群并不能正确的形成。因为原先的单节点集群无法完成`leader`的选举。
直到新节点启动完，和原先的节点建立连接以后，新集群才能正确形成。

### 服务故障恢复

在使用etcd集群的过程中，有时会出现少量主机故障，这时我们需要对集群进行维护。然而，在现实情况下，还可能遇到由于严重的设备或网络的故障，导致超过半数的节点无法正常工作。

在etcd集群无法提供正常的服务，我们需要用到一些备份和数据恢复的手段。etcd背后的raft，保证了集群的数据的一致性与稳定性。所以我们对etcd的恢复，更多的是恢复etcd的节点服务，并还原用户数据。

首先，从剩余的正常节点中选择一个正常的成员节点， 使用 `etcdctl backup` 命令备份etcd数据。

```shell
$ ./etcdctl backup --data-dir /var/lib/etcd -backup-dir /tmp/etcd_backup
$ tar -zcxf backup.etcd.tar.gz /tmp/etcd_backup
```

这个命令会将节点中的用户数据全部写入到指定的备份目录中，但是节点ID,集群ID等信息将会丢失， 并在恢复到目的节点时被重新。这样主要是防止原先的节点意外重新加入新的节点集群而导致数据混乱。

然后将Etcd数据恢复到新的集群的任意一个节点上， 使用 `--force-new-cluster` 参数启动Etcd服务。这个参数会重置集群ID和集群的所有成员信息，其中节点的监听地址会被重置为localhost:2379, 表示集群中只有一个节点。

```shell
$ tar -zxvf backup.etcd.tar.gz -C /var/lib/etcd
$ etcd --data-dir=/var/lib/etcd --force-new-cluster ...
```

启动完成单节点的etcd,可以先对数据的完整性进行验证， 确认无误后再通过Etcd API修改节点的监听地址，让它监听节点的外部IP地址，为增加其他节点做准备。例如：

用etcd命令找到当前节点的ID。

```shell
$ etcdctl member list 

98f0c6bf64240842: name=cd-2 peerURLs=http://127.0.0.1:2580 clientURLs=http://127.0.0.1:2579
```

由于etcdctl不具备修改成员节点参数的功能， 下面的操作要使用API来完成。

```shell
$ curl http://127.0.0.1:2579/v2/members/98f0c6bf64240842 -XPUT \
 -H "Content-Type:application/json" -d '{"peerURLs":["http://127.0.0.1:2580"]}'
```

注意，在Etcd文档中， 建议首先将集群恢复到一个临时的目录中，从临时目录启动etcd，验证新的数据正确完整后，停止etcd，在将数据恢复到正常的目录中。

最后，在完成第一个成员节点的启动后，可以通过集群扩展的方法使用 `etcdctl member add` 命令添加其他成员节点进来。

---

## 扩展etcd集群

在集群中的任何一台etcd节点上执行命令，将新节点注册到集群：

```
curl http://127.0.0.1:2379/v2/members -XPOST -H "Content-Type: application/json" -d '{"peerURLs": ["http://192.168.73.172:2380"]}'
```

在新节点上启动etcd容器，注意-initial-cluster-state参数为existing

```
/usr/local/etcd/etcd \-name etcd03 \-advertise-client-urls http://192.168.73.150:2379,http://192.168.73.150:4001 \-listen-client-urls http://0.0.0.0:2379 \-initial-advertise-peer-urls http://192.168.73.150:2380 \-listen-peer-urls http://0.0.0.0:2380 \-initial-cluster-token etcd-cluster \-initial-cluster "etcd01=http://192.168.73.140:2380,etcd02=http://192.168.73.137:2380,etcd03=http://192.168.73.150:2380" \-initial-cluster-state existing
```

任意节点执行健康检查：

```
[root@docker01 ~]# etcdctl cluster-healthmember 2bd5fcc327f74dd5 is healthy: got healthy result from http://192.168.73.140:2379member c8a9cac165026b12 is healthy: got healthy result from http://192.168.73.137:2379cluster is healthy
```

## Etcd数据迁移

#### 数据迁移

在 gzns-inf-platform53.gzns.baidu.com 机器上运行着一个 etcd 服务器，其 data-dir 为 /var/lib/etcd/。我们要以 /var/lib/etcd 中的数据为基础，搭建一个包含三个节点的高可用的 etcd 集群，三个节点的主机名分别为：

```
gzns-inf-platform53.gzns.baidu.com gzns-inf-platform56.gzns.baidu.com gzns-inf-platform60.gzns.baidu.com
```

#### 初始化一个新的集群

我们先分别在上述三个节点上创建 /home/work/etcd/data-dir/ 文件夹当作 etcd 集群每个节点的数据存放目录。然后以 gzns-inf-platform60.gzns.baidu.com 节点为起点创建一个单节点的 etcd 集群，启动脚本 force-start-etcd.sh 如下：

```
#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd2 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform60.gzns.baidu.com:2379,http://gzns-inf-platform60.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform60.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380 --force-new-cluster > ./log/etcd.log 2>&1
```

这一步的 **--force-new-cluster** 很重要，可能是为了抹除旧 etcd 的一些属性信息，从而能成功的创建一个单节点 etcd 的集群。

这时候通过

```
etcdctl member list
```

查看 peerURLs 指向的是不是 `http://gzns-inf-platform60.gzns.baidu.com:2380` ? 如果不是，需要更新这个 etcd 的 peerURLs 的指向，否则这样在加入新的节点时会失败的。

我们手动更新这个 etcd 的 peerURLs 指向

```
etcdctl member update ce2a822cea30bfca http://gzns-inf-platform60.gzns.baidu.com:2380
```

#### 添加etcd1成员

然后添加 gzns-inf-platform56.gzns.baidu.com 节点上的 etcd1 成员

```
etcdctl member add etcd1 http://gzns-inf-platform56.gzns.baidu.com:2380
```

注意要先添加 etcd1 成员后，再在 gzns-inf-platform56.gzns 机器上启动这个 etcd1 成员

这时候我们登陆上 gzns-inf-platform56.gzns.baidu.com 机器上启动这个 etcd1 实例，启动脚本 force-start-etcd.sh 如下：

```
#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd1 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform56.gzns.baidu.com:2379,http://gzns-inf-platform56.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform56.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1
```

注意在这个节点上我们先把 data-dir 文件夹中的数据删除（如果有内容的情况下），然后设置 --initial-cluster和 --initial-cluster-state。

#### 添加 etcd 成员

这时候我们可以通过

```
etcdctl member list
```

观察到我们新加入的节点了，然后我们再以类似的步骤添加第三个节点 gzns-inf-platform53.gzns.baidu.com上 的 etcd0 实例

```
etcdctl member add etcd0 http://gzns-inf-platform53.gzns.baidu.com:2380
```

然后登陆到 gzns-inf-platform53.gzns.baidu.com 机器上启动 etcd0 这个实例，启动脚本 force-start-etcd.sh 如下：

```
#!/bin/bash

# Don't start it unless etcd cluster has a heavily crash !

../bin/etcd --name etcd0 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform53.gzns.baidu.com:2379,http://gzns-inf-platform53.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform53.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380,etcd0=http://gzns-inf-platform53.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1
```

过程同加入 etcd1 的过程相似，这样我们就可以把单节点的 etcd 数据迁移到一个包含三个 etcd 实例组成的集群上了。

#### 大体思路

先通过 --force-new-cluster 强行拉起一个 etcd 集群，抹除了原有 data-dir 中原有集群的属性信息（内部猜测），然后通过加入新成员的方式扩展这个集群到指定的数目。

## 高可用etcd集群方式（可选择）

上面数据迁移的过程一般是在紧急的状态下才会进行的操作，这时候可能 etcd 已经停掉了，或者节点不可用了。在一般情况下如何搭建一个高可用的 etcd 集群呢，目前采用的方法是用 supervise 来监控每个节点的 etcd 进程。

在数据迁移的过程中，我们已经搭建好了一个包含三个节点的 etcd 集群了，这时候我们对其做一些改变，使用supervise 重新拉起这些进程。

首先登陆到 gzns-inf-platform60.gzns.baidu.com 节点上，kill 掉 etcd 进程，编写 etcd 的启动脚本 start-etcd.sh，其中 start-etcd.sh 的内容如下：

```
#!/bin/bash
../bin/etcd --name etcd2 --data-dir /home/work/etcd/data-dir --advertise-client-urls http://gzns-inf-platform60.gzns.baidu.com:2379,http://gzns-inf-platform60.gzns.baidu.com:4001 --listen-client-urls http://0.0.0.0:2379,http://0.0.0.0:4001 --initial-advertise-peer-urls http://gzns-inf-platform60.gzns.baidu.com:2380 --listen-peer-urls http://0.0.0.0:2380 --initial-cluster-token etcd-cluster-1 --initial-cluster etcd2=http://gzns-inf-platform60.gzns.baidu.com:2380,etcd1=http://gzns-inf-platform56.gzns.baidu.com:2380,etcd0=http://gzns-inf-platform53.gzns.baidu.com:2380 --initial-cluster-state existing > ./log/etcd.log 2>&1
```

然后使用 supervise 执行 start-etcd.sh 这个脚本，使用 supervise 启动 start-etcd.sh 的启动脚本 etcd_control 如下：

```
#!/bin/sh

if [ $# -ne 1 ]; then
    echo "$0: start|stop"
fi


work_path=`dirname $0`
cd ${work_path}
work_path=`pwd`

supervise=${work_path}/supervise/bin/supervise64.etcd
mkdir -p ${work_path}/supervise/status/etcd


case "$1" in
start) 
    killall etcd supervise64.etcd
    ${supervise} -f "sh ./start-etcd.sh" \
        -F ${work_path}/supervise/conf/supervise.conf  \
        -p  ${work_path}/supervise/status/etcd
    echo "START etcd daemon ok!"
;;
stop)
    killall etcd supervise64.etcd
    if [ $? -ne 0 ] 
    then
        echo "STOP etcd daemon failed!"
        exit 1
    fi  
    echo "STOP etcd daemon ok!"
```

这里为什么不直接用 supervise 执行 etcd 这个命令呢，反而以一个 start-etcd.sh 脚本的形式启动这个 etcd 呢？原因在于我们需要将 etcd 的输出信息重定向到文件中，

如果直接在 supervise 的 command 进行重定向，将发生错误。

分别登陆到以下两台机器

- gzns-inf-platform56.gzns.baidu.com
- gzns-inf-platform53.gzns.baidu.com

上进行同样的操作，注意要针对每个节点的不同修改对应的etcd name 和 peerURLs 等。

## 常见问题

**1、etcd 读取已有的 data-dir 数据而启动失败，常常表现为cluster id not match什么的**

可能原因是新启动的 etcd 属性与之前的不同，可以尝 --force-new-cluster 选项的形式启动一个新的集群

**2、etcd 集群搭建完成后，通过 kubectl get pods 等一些操作发生错误的情况**

目前解决办法是重启一下 apiserver 进程

**3、还是 etcd启动失败的错误，大多数情况下都是与data-dir 有关系，data-dir 中记录的信息与 etcd启动的选项所标识的信息不太匹配造成的**

如果能通过修改启动参数解决这类错误就最好不过的了，非常情况下的解决办法：

- 一种解决办法是删除data-dir文件
- 一种方法是复制其他节点的data-dir中的内容，以此为基础上以 --force-new-cluster 的形式强行拉起一个，然后以添加新成员的方式恢复这个集群，这是目前的几种解决办法

---

开始环境是单节点，存储数据一段时间后发现需要集群高可用环境，幸亏etcd支持在线扩容

1. 修改单节点配置并重启etcd

```shell
# cat /etc/etcd/etcd.conf
ETCD_NAME=k8s1
ETCD_DATA_DIR="/data/etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_LISTEN_PEER_URLS="http://172.17.3.20:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.17.3.20:2380"
ETCD_INITIAL_CLUSTER="k8s1=http://172.17.3.20:2380"
```

备注后三行是新增，后重启etcd

2. 注册新节点

注册新节点

```shell
# curl http://127.0.0.1:2379/v2/members -XPOST -H "Content-Type: application/json" -d '{"peerURLs": ["http://172.17.3.7:2380"]}'
{"id":"dd224433fd05e450","name":"","peerURLs":["http://172.17.3.7:2380"],"clientURLs":[]}
```

注意只注册未启动新节点时集群状态是不健康的；

```shell
#  curl  http://172.17.3.20:2379/v2/members
{"members":[{"id":"869f0c691c5458a3","name":"k8s1","peerURLs":["http://172.17.3.20:2380"],"clientURLs":["http://0.0.0.0:2379"]},
{"id":"dd224433fd05e450","name":"","peerURLs":["http://172.17.3.7:2380"],"clientURLs":[]}]}

# etcdctl cluster-health
member 869f0c691c5458a3 is unhealthy: got unhealthy result from http://0.0.0.0:2379
member dd224433fd05e450 is unreachable: no available published client urls
cluster is unhealthy
```

3. 启动新节点

```shell
# cat /etc/etcd/etcd.conf
ETCD_NAME=k8s2
ETCD_DATA_DIR="/data/etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_LISTEN_PEER_URLS="http://172.17.3.7:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.17.3.7:2380"
ETCD_INITIAL_CLUSTER="k8s1=http://172.17.3.20:2380,k8s2=http://172.17.3.7:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
```

这是新节点配置，后启动新节点

4. 检测新节点

```shell
# etcdctl cluster-health
member 869f0c691c5458a3 is healthy: got healthy result from http://0.0.0.0:2379
member dd224433fd05e450 is healthy: got healthy result from http://0.0.0.0:2379
cluster is healthy
```

5. 重复上面操作添加新节点

添加第二个新节点后效果

```shell
# curl  http://172.17.3.20:2379/v2/members
{"members":[{"id":"29e27bbd848a2e50","name":"k8s3","peerURLs":["http://172.17.3.8:2380"],"clientURLs":["http://0.0.0.0:2379"]},
{"id":"869f0c691c5458a3","name":"k8s1","peerURLs":["http://172.17.3.20:2380"],"clientURLs":["http://0.0.0.0:2379"]},{"id":"dd224433fd05e450","name":"k8s2","peerURLs":
["http://172.17.3.7:2380"],"clientURLs":["http://0.0.0.0:2379"]}]}

# etcdctl cluster-health
member 29e27bbd848a2e50 is healthy: got healthy result from http://0.0.0.0:2379
member 869f0c691c5458a3 is healthy: got healthy result from http://0.0.0.0:2379
member dd224433fd05e450 is healthy: got healthy result from http://0.0.0.0:2379
cluster is healthy
```

6. 最后修改所有节点配置为一致

```shell
# cat /etc/etcd/etcd.conf
ETCD_NAME=k8s1
ETCD_DATA_DIR="/data/etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_LISTEN_PEER_URLS="http://172.17.3.20:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.17.3.20:2380"
ETCD_INITIAL_CLUSTER="k8s1=http://172.17.3.20:2380,k8s2=http://172.17.3.7:2380,k8s3=http://172.17.3.8:2380"
ETCD_INITIAL_CLUSTER_STATE="existing"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
```

7. 更新访问etcd集群参数kube-apiserver与flanneld

```shell
KUBE_ETCD_SERVERS="--etcd-servers=http://172.17.3.20:2379,http://172.17.3.7:2379,http://172.17.3.8:2379"
```

8. 集群配置文件备份脚本

```shell
# cat /data/scripts/backupetcd.sh 
#!/bin/bash
date_time=`date +%Y%m%d`
etcdctl backup --data-dir /data/etcd/ --backup-dir /data/etcd_backup/${date_time}
find /data/etcd_backup/ -ctime +7 -exec rm -r {} \;
```

9. 故障排查

注意各节点时钟相差过大导致集群建立不起来，所以需要先做时钟同步，默认1s内时差才能成功

注意如果其中有etcd节点启动不起来，可以etcdctl rember delete 后重新添加，删除时清空/data/etcd数据，注意至少要有一份数据保存，这样才能同步到其他节点

---

etcd是一个用于存储关键数据的键值存储，zookeeper是一个用于管理配置等信息的中心化服务。

etcd 的使用其实非常简单，它对外提供了 gRPC 接口，我们可以通过 Protobuf 和 gRPC 直接对 etcd 中存储的数据进行管理，也可以使用官方提供的 etcdctl 操作存储的数据。

ZooKeeper和etcd都是强一致的（满足CAP的CP），意味着无论你访问任意节点，都将获得最终一致的数据视图。这里最终一致比较重要，因为ZooKeeper使用的Paxos和etcd使用的Raft都是Quorum机制（大多数同意原则），所以部分节点可能因为任何原因延迟收到更新，但数据将最终一致，高度可靠。

ZooKeeper从逻辑上来看是一种目录结构，而etcd从逻辑上来看就是一个K-V结构。etcd的key可以是任意字符串，所以仍旧可以模拟出目录。etcd在存储上实现了key有序排列，因此/a/b，/a/b/c，/a/b/d在存储中顺序排列的，通过定位到key=/a/b并依次顺序向后扫描，就会遇到/a/b/c与/a/b/d这两个孩子，从而一样可以实现父子目录关系，所以我们在设计模型与使用etcd时仍旧沿用ZooKeeper的目录表达方式。**etcd本质上是一个有序的K-V存储**。

---

```shell
 每个etcd的key都一个modifyIndex，这个modifyIndex会随着写操作的变更而增加，通常etcd的集群v2的版本会默认缓存最后1000次变更，当次期间的变更超过1000时，会根据wal的相关写日志进行追写，但是在v2数据转换的过程中时间较长，会有部分的可能导致集群中某些几点的ModifyIndex永远无法更新。升级后可以通过如下方式进行检查 (假设集群为三个节点的集群)

   
curl http://etcd1:2379/v2/keys/some_key_not_exists
curl http://etcd2:2379/v2/keys/some_key_not_exists
curl http://etcd3:2379/v2/keys/some_key_not_exists
 
此时etcd的server会返回一个不存在的提示，并将当前系统的modifyIndex通过结果反馈回来，如果发现三个节点的modifyIndex有比较大差异，说明与master不同的节点已经损坏，且这种损坏是无法通过wal追写恢复的。好在此时etcd的集群的选主是没有问题的，只需要将-initial-cluster-state设置为existing，并删除当前节点的数据文件，并重启etcd即可恢复
```

---

#### 一致性协议与复制状态机

一致性就是不同的副本服务器认可同一份数据，一旦这些服务器对某份数据达成了一致，那么该决定便是最终的决定，且未来也无法推翻。

一致性协议是在复制状态机的背景下提出来的，通常也应用于具有复制状态语义的场景。复制状态机只是保证所有的状态机都以相同的顺序执行这些命令。

顺序一致性，也称为可序列化，是指所有的进程都以相同的顺序看到所有的修改。

---

```shell
启动集群后，etcd进程会把配置信息写入到指定的数据目录。配置信息包括：member ID、cluster ID和集群初始化配置信息。数据分为两种：WAL和SNAP，WAL记录member的操作信息，SNAP则用来恢复该集群。

配置专门存储WAL文件的磁盘可以改善集群的吞吐量，让集群运行稳定。强烈推荐为WAL文件配置专门的磁盘，并在集群启动时使用--wal-dir来指定WAL文件的存储位置。

当一个节点的数据目录无法恢复或不可用，应该使用etcdctl命令将此节点从集群中移除。

此外，还应当避免通过旧数据目录来恢复etcd集群！！！！！！Once removed the member can be re-added with an empty data directory.
```

