### 集群资源需求

**CPU**

```
kubernetes官方推荐使用etcd集群最佳的节点数为3-5台，在容器方案可行的情况下，采用3个节点组成etcd集群作为过渡；coreos官方推荐中小型etcd集群可以选用2-4颗cpus，考虑到容器和虚拟机并存并向容器化过渡的情况，这里建议：
选择4核心的cpu，以3个节点组成etcd集群
```

**memory**

```
etcd has a relatively small memory footprint but its performance still depends on having enough memory. An etcd server will aggressively cache key-value data and spends most of the rest of its memory tracking watchers. Typically 8GB is enough. For heavy deployments with thousands of watchers and millions of keys, allocate 16GB to 64GB memory accordingly.
etcd集群的性能也依赖于物理内存大小，对于中小型etcd集群，8G内存的分配可以满足需要。
```

**disk**

```
A slow disk will increase etcd request latency and potentially hurt cluster stability. Since etcd’s consensus protocol depends on persistently storing metadata to a log, a majority of etcd cluster members must write every request down to disk. Additionally, etcd will also incrementally checkpoint its state to disk so it can truncate this log. If these writes take too long, heartbeats may time out and trigger an election, undermining the stability of the cluster.
etcd集群对磁盘的读写速度要求很高，直接影响etcd集群的性能和稳定性。官方推荐使用SSD硬盘，
若使用SSD硬盘，在三个节点以上的etcd集群中，etcd的RAFT算法可以保证数据的强一致性，不需要对硬盘再做RAID处理。
```

参考：

[资源评估](https://coreos.com/etcd/docs/latest/op-guide/hardware.html#small-cluster)

[etcd集群](https://kubernetes.io/docs/setup/independent/high-availability/#establishing-a-redundant-reliable-data-storage-layer)

### 启动集群

```
docker run -d --name etcd --restart always \
  -p 4001:4001 \
  -p 2379:2379 \
  -p 2380:2380 \
  -v /etc/ssl/certs:/etc/ssl/certs \
  -v /var/lib/etcd-cluster:/var/lib/etcd \
  gcr.io/google_containers/etcd-amd64:3.0.17 etcd \
  --name=$currentHost \
  --initial-advertise-peer-urls=http://$currentIp:2380 \
  --listen-peer-urls=http://0.0.0.0:2380 \
  --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
  --advertise-client-urls=http://$currentIp:2379 \
  --initial-cluster-token=k8s-etcd-cluster \
  --initial-cluster=$cluster \
  --initial-cluster-state=new \
  --auto-tls \
  --peer-auto-tls \
  --data-dir=/var/lib/etcd
```

**some notes：**

```
1. port 4001，client-urls监听的端口通常为2379，老版本使用的就是4001
2. port 2379，新版etcd监听客户端请求的url可以配置成多个，这样可以配合多块网卡同时监听不通网络下的请求
3. port 2380，peer-urls监听的端口通常为2380，包括所有已经在集群中正常工作的所有节点的地址
4. peer，对同一个etcd集群中另外一个member的称呼
5. client，向etcd集群中发送HTTP请求的客户端

RAFT，etcd所采用的保证分布式系统强一致性的算法
member，一个etcd实例，管理着一个node
WAL，预写式日志，etcd用于持久化存储的日志格式
snapshot，etcd防止WAL文件过多而设置的快照，存储etcd数据状态
```

**参数说明**

etcd有三种集群化启动的配置方案，分别为静态配置启动、etcd自身服务发现、通过DNS进行服务发现；**我们采用静态配置启动**。

```
--name，集群中member的名称标识；
--listen-peer-urls，etcd服务监听的集群成员的url列表，格式为，http://IP:2380
--listen-client-urls，etcd服务监听的接收HTTP请求的url列表，格式为http://IP:2379
```

```
--advertise-client-urls，etcd集群中接收HTTP请求的地址列表，格式为http://$currentIp:2379 \
--initial-advertise-peer-urls，etcd集群中数据交互的地址列表，格式为http://$currentIp:2380 \
--initial-cluster-token，初始化集群配置的token认证，这样可以确保每个集群和集群的成员都拥有独特的ID
--initial-cluster，初始化集群启动时的URL配置，是k-v格式，包含所有节点的URL信息
--initial-cluster-state，初始化集群状态有new和existing两种，new状态是静态方式初始化集群的状态，existing状态是当有新节点要加入集群时，新节点上应当设置的状态
--auto-tls \
--peer-auto-tls \
--data-dir=/var/lib/etcd
```

**安装脚本**

```shell
sh install.sh hostname1:ip1 hostname2:ip2 hostname3:ip3
#!/bin/bash
function run()
{
    currentHost=$1
    currentIp=$2
    cluster=$3

    systemctl stop etcd
    systemctl disable etcd
    docker stop etcd && docker rm etcd
    rm -rf /var/lib/etcd-cluster
    mkdir -p /var/lib/etcd-cluster

    docker run -d --name etcd --restart always \
      --network host \
      -v /etc/ssl/certs:/etc/ssl/certs \
      -v /var/lib/etcd-cluster:/var/lib/etcd \
      gcr.io/google_containers/etcd-amd64:3.1.10 etcd \
      --name=$currentHost \
      --initial-advertise-peer-urls=http://$currentIp:2380 \
      --listen-peer-urls=http://0.0.0.0:2380 \
      --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
      --advertise-client-urls=http://$currentIp:2379 \
      --initial-cluster-token=k8s-etcd-cluster \
      --initial-cluster=$cluster \
      --initial-cluster-state=new \
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
