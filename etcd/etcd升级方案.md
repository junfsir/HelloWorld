#### 摘要

etcd集群支持滚动升级，即将集群中的实例依次停掉之后，使用新版本的镜像启动。升级过程中，etcd支持集群内的节点存在混合版本，并且使用最低版本的协议通信。当集群内的所有实例都升级完成后才算整个集群升级完毕。集群内的实例通过相互通信来决定集群的总体版本，这个总体版本就是对外报告的版本以及提供特性的依据。另外，只要集群中的实例还存在一个低版本，就可以通过替换镜像来实现回退。若实例均已升级完成，则无法实现降级，只能通过之前备份的数据恢复服务。

#### 升级过程

1. 确认集群的健康状态

```shell
# ETCD_API=3 etcdctl --endpoints 10.204.0.21:2379 cluster-health
# ETCDCTL_API=3 etcdctl --write-out="table" --endpoints='10.204.0.21:2379,10.204.0.43:2379,10.204.0.37:2379' endpoint health
# ETCDCTL_API=3 etcdctl --write-out="table" --endpoints='10.204.0.21:2379,10.204.0.43:2379,10.204.0.37:2379' endpoint status
```

2. 备份数据

```shell
# ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 snapshot save /data/backup.db
```



2. 停止某一实例，并使用新版本启动

*注意：*原来实例的数据存储路径下的数据不要删除，若删除升级过程会出现异常，如下

```shell
2019-07-08 02:52:35.948961 I | raft: 85cd0fe00f97d220 [term: 1] received a MsgHeartbeat message with higher term from 773124fa7aa88a0e [term: 26]
2019-07-08 02:52:35.949537 I | raft: 85cd0fe00f97d220 became follower at term 26
2019-07-08 02:52:35.949600 C | raft: tocommit(260650) is out of range [lastIndex(0)]. Was the raft log corrupted, truncated, or lost?
panic: tocommit(260650) is out of range [lastIndex(0)]. Was the raft log corrupted, truncated, or lost?
```

```shell
修改etcd安装脚本的镜像，启动即可
#!/bin/bash
function run()
{
    currentHost=$1
    currentIp=$2
    cluster=$3

    systemctl stop etcd
    systemctl disable etcd
    docker stop etcd && docker rm etcd

    docker run -d --name etcd --restart always \
      --network host \
      -v /etc/ssl/certs:/etc/ssl/certs \
      -v /var/lib/etcd-cluster:/var/lib/etcd \
      hub.hexin.cn:9082/ths/etcd-amd64:3.2.18 etcd \
      --name="k8s-dev-0-21" \
      --initial-advertise-peer-urls=http://$currentIp:2380 \
      --listen-peer-urls=http://0.0.0.0:2380 \
      --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
      --advertise-client-urls=http://$currentIp:2379 \
      --initial-cluster-token=k8s-etcd-cluster \
      --initial-cluster="k8s-dev-0-21=http://10.204.0.21:2380,k8s-test-0-37=http://10.204.0.37:2380,k8s-test-0-43=http://10.204.0.43:2380" \
      --initial-cluster-state="existing" \
      --auto-tls \
      --peer-auto-tls \
      --data-dir=/var/lib/etcd
    docker exec  etcd etcdctl cluster-health
}

function usage()
{
    echo "install.sh hostname1:ip1 hostname2:ip2 hostname3:ip3"
}

function init()
{
    OLD_IFS="$IFS" 
    host=`hostname`
    currentHost=""
    currentIp=""
    cluster=""

    for arg in "$@"
    do
        IFS=":"
        arr=($arg) 
        IFS="$OLD_IFS" 
        if [ ${#arr[*]} = 2 ] 
        then
            isCurrentIp=`ip addr|grep ${arr[1]}|wc -l`
            if [ ${arr[0]} = $host -a $isCurrentIp = 1 ]
            then
                currentHost=$host
                currentIp=${arr[1]}
            fi

            if [[ $cluster = "" ]]
            then
                cluster="${arr[0]}=http://${arr[1]}:2380"
            else
                cluster="$cluster,${arr[0]}=http://${arr[1]}:2380"
            fi
        fi
    done

    if [ "$currentHost" = "" -a "$currentIp" = "" ]
    then
        echo "current node is not in list"
        exit 1
    fi
    run $currentHost $currentIp $cluster
}

if [ ! $1 ]
then
    usage
    exit 1
fi

init $@

```

3. 所有实例升级完成之后，观察某一实例的日志可以看到如下信息则升级完成

```shell
2019-07-08 03:11:07.923087 I | etcdserver: updating the cluster version from 3.1 to 3.2
2019-07-08 03:11:07.936244 N | etcdserver/membership: updated the cluster version from 3.1 to 3.2
2019-07-08 03:11:07.936379 I | etcdserver/api: enabled capabilities for version 3.2
```

#### 降级

此步骤针对集群升级完成之后的降级操作

```shell
将备份的snapshot restore之后重新启动实例即可
```
