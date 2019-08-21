`kubernetes`刚开始落地的时候，`etcd`采用集群外、单节点模式，现在，业务量逐渐变大，为保证平台稳定性及高吞吐量，需对`etcd`进行扩容。线上版本采用的是`3.1.10`，支持在线扩容。

`first inform the cluster of the new configuration and then start the new member`

分三步走：

1、在原来节点的基础上`member add`，要注意的是`member add`之后要先将新节点启动，再`member add`另外一个；

查看集群状态

```shell
# ETCDCTL_API=3 etcdctl --endpoints http://10.204.0.22:2379 endpoint status
# ETCDCTL_API=3 etcdctl --endpoints http://10.204.0.22:2379 endpoint health
# ETCD_API=3 etcdctl --endpoints http://10.204.0.22:2379 cluster-health
# ETCDCTL_API=3 etcdctl --write-out="table" --endpoints='10.204.0.22:2379,10.204.0.65:2379,10.204.0.67:2379' member list
# ETCDCTL_API=3 etcdctl --write-out="table" --endpoints='10.204.0.22:2379,10.204.0.65:2379,10.204.0.67:2379' endpoint status
```

```shell
新增一个member
# ETCDCTL_API=3 etcdctl member add k8s-dev-12-126 --peer-urls="http://10.0.12.126:2380"
会返回3个变量，启动新节点时，在create-etcd.sh中修改对应变量即可
--name="k8s-test-0-45"
--initial-cluster="docker22=http://10.204.0.22:2380,k8s-test-0-65=http://10.204.0.65:2380"
--initial-cluster-state="existing"
新增一个member
# etcdctl member add k8s-dev-12-72 --peer-urls="http://10.0.12.72:2380"
查看当前集群状态
# curl 'http://127.0.0.1:2379/v2/stats/leader'|python -mjson.tool
```

2、启动新节点；

```shell
# vim create-etcd.sh
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
      k8s.gcr.io/etcd-amd64:3.1.12  etcd \
      --name="k8s-dev-12-126" \
      --initial-advertise-peer-urls=http://$currentIp:2380 \
      --listen-peer-urls="http://10.0.12.126:2380" \
      --listen-client-urls=http://0.0.0.0:2379,http://0.0.0.0:4001 \
      --advertise-client-urls=http://$currentIp:2379 \
      --initial-cluster-token=k8s-etcd-cluster \
      --initial-cluster="k8s-dev-12-71=http://10.0.12.71:2380,k8s-dev-12-126=http://10.0.12.126:2380" \
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
# sh create-etcd.sh k8s-dev-12-71:10.0.12.71
```

3、配置`apiserver`；

```yaml
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v1.10.5
apiServerCertSANs:
- 10.0.12.126
- 10.0.12.72
- 10.0.12.71
- ${CP0_HOSTNAME}
- ${CP1_HOSTNAME}
- ${CP2_HOSTNAME}
- ${VIP}
etcd:
  endpoints:
  - http://10.0.12.126:2379
  - http://10.0.12.71:2379
  - http://10.0.12.72:2379
networking:
  podSubnet: "10.244.0.1/16"
```

重签证书

```shell
pushd /etc/kubernetes;
    rm admin.conf controller-manager.conf kubelet.conf scheduler.conf pki/apiserver.crt pki/apiserver.key
    # Generates an API server serving certificate and key
    kubeadm alpha phase certs apiserver --config /etc/kubernetes/kubeadm-config.yaml
    # Generates all kubeconfig files necessary to establish the control plane and the admin kubeconfig file
    kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml
    echo "Restarting apiserver/controller/scheduler containers."
    docker ps|grep -E 'k8s_kube-scheduler|k8s_kube-controller-manager|k8s_kube-apiserver'|awk '{print $1}'|xargs -i docker rm -f {} > /dev/null
    systemctl restart kubelet
    cp /etc/kubernetes/admin.conf ~/.kube/config
popd
```

修改`apiserver`配置

```shell
vim /etc/kubernetes/manifests/kube-apiserver.yaml
--etcd-servers=http://10.0.12.126:2379,http://10.0.12.71:2379,http://10.0.12.72:2379
```

问题：

The new member will run as a part of the cluster and immediately begin catching up with the rest of the cluster.

If adding multiple members the best practice is to configure a single member at a time and verify it starts correctly before adding more new members. *If adding a new member to a 1-node cluster, the cluster cannot make progress before the new member starts because it needs two members as majority to agree on the consensus. This behavior only happens between the time `etcdctl member add` informs the cluster about the new member and the new member successfully establishing a connection to the existing one.*

### 备份

```shell
ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 snapshot save /data/snapshotdb_backup.db
```

### 还原

```shell
#!/bin/bash
HOST=$1
IP=$2
SNAPFILE=$3
docker stop etcd && docker rm etcd
docker stop etcd-restore && docker rm etcd-restore
rm -fr /var/lib/etcd-cluster
rm -fr /var/lib/etcd
docker run  --name etcd-restore -e ETCDCTL_API=3   --network host \
	-v /etc/ssl/certs:/etc/ssl/certs \
	-v /var/lib:/var/lib \
	hub.hexin.cn:9082/k8s/etcd-amd64:3.1.10   etcdctl \
	snapshot restore $SNAPFILE \
	--name $HOST \
	--initial-cluster $HOST=http://$IP:2380 \
	--initial-cluster-token k8s-etcd-cluster \
	--data-dir=/var/lib/etcd-cluster \
	--initial-advertise-peer-urls http://$IP:2380
docker run -d --name etcd --restart always \
    --network host \
        -v /etc/ssl/certs:/etc/ssl/certs \
        -v /var/lib/etcd-cluster:/var/lib/etcd \
       hub.hexin.cn:9082/k8s/etcd-amd64:3.1.10 etcd \
    --name $HOST \
    --listen-client-urls http://$IP:2379 \
    --advertise-client-urls http://$IP:2379 \
    --data-dir=/var/lib/etcd \
    --listen-peer-urls http://$IP:2380  \
    --initial-cluster-state=new &
```

```
将snapshotdb.db文件拷贝到要还原的宿主机上运行还原脚本:
sh  etcd.sh yfb-0-137 10.205.0.137 /var/lib/snapshot201807111148.db 
```

测试环境实施

```shell
ETCDCTL_API=3 etcdctl --endpoints 127.0.0.1:2379 snapshot save /data/snapshotdb_backup.db

ETCD_API=3 etcdctl member add k8s-test-0-65 http://10.204.0.65:2380
sh install-etcd.sh k8s-test-0-65:10.204.0.65

ETCD_API=3 etcdctl member add k8s-test-0-67 http://10.204.0.67:2380
sh install-etcd.sh k8s-test-0-67:10.204.0.67
```

---

*上述备份恢复操作仅适用于单实例模式。集群恢复仅需一个快照文件，所有节点都将从同一个快照文件进行恢复。恢复会覆写快照文件中的一些元数据，例如，`member ID`和`cluster ID`，这些节点也就丢失了他们之前的身份信息。抹掉元数据是为了防止新节点不小心加入别的etcd集群。*

#### Snapshotting the keyspace

```shell
$ ETCDCTL_API=3 etcdctl --endpoints $ENDPOINT snapshot save snapshot.db
```

#### Restoring a cluster

```shell
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m1 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host1:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m2 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host2:2380
$ ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --name m3 \
  --initial-cluster m1=http://host1:2380,m2=http://host2:2380,m3=http://host3:2380 \
  --initial-cluster-token etcd-cluster-1 \
  --initial-advertise-peer-urls http://host3:2380
```

```shell
$ etcd \
  --name m1 \
  --listen-client-urls http://host1:2379 \
  --advertise-client-urls http://host1:2379 \
  --listen-peer-urls http://host1:2380 &
$ etcd \
  --name m2 \
  --listen-client-urls http://host2:2379 \
  --advertise-client-urls http://host2:2379 \
  --listen-peer-urls http://host2:2380 &
$ etcd \
  --name m3 \
  --listen-client-urls http://host3:2379 \
  --advertise-client-urls http://host3:2379 \
  --listen-peer-urls http://host3:2380 &
```

#### 集群数据备份

```shell
#!/bin/bash
#
ETCDCTL_PATH='/usr/etcd/bin/etcdctl'
ENDPOINTS='1.1.1.1:2379,1.1.1.2:2379,1.1.1.3:2379'
BACKUP_DIR='/home/apps/backup'
DATE=`date +%Y%m%d-%H%M%S`
[ ! -d $BACKUP_DIR ] && mkdir -p $BACKUP_DIR
export ETCDCTL_API=3;$ETCDCTL_PATH --endpoints=$ENDPOINTS snapshot save $BACKUP_DIR/snapshot-$DATE\.db
cd $BACKUP_DIR;ls -lt $BACKUP_DIR|awk '{if(NR>11){print "rm -rf "$9}}'|sh
```

#### 启用https后的恢复脚本

```shell
#!/bin/bash
HOST=$1
IP=$2
SNAPFILE=$3
docker stop etcd && docker rm etcd
docker stop etcd-restore && docker rm etcd-restore
rm -fr /var/lib/etcd-cluster
rm -fr /var/lib/etcd
docker run    --name etcd-restore -e ETCDCTL_API=3   --network host \
    -v /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd \
    -v /var/lib:/var/lib \
    hub.hexin.cn:9082/k8s/etcd-amd64:3.1.10   etcdctl \
    snapshot restore $SNAPFILE \
    --name $HOST \
    --initial-cluster $HOST=https://$IP:2380 \
    --initial-cluster-token k8s-etcd-cluster \
    --data-dir=/var/lib/etcd-cluster \
    --initial-advertise-peer-urls https://$IP:2380 \
    --cacert=/etc/kubernetes/pki/etcd/ca.pem \
    --cert=/etc/kubernetes/pki/etcd/client.pem \
    --key=/etc/kubernetes/pki/etcd/client-key.pem
docker run -d --name etcd --restart always \
    --network host \
        -v  /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd \
        -v /var/lib/etcd-cluster:/var/lib/etcd \
       hub.hexin.cn:9082/k8s/etcd-amd64:3.1.10 etcd \
    --name $HOST \
    --listen-client-urls https://$IP:2379 \
    --advertise-client-urls https://$IP:2379 \
    --data-dir=/var/lib/etcd \
    --listen-peer-urls https://$IP:2380  \
    --initial-cluster-state=new \
    --auto-tls \
    --peer-auto-tls \
    --data-dir=/var/lib/etcd \
    --cert-file=/etc/kubernetes/pki/etcd/server.pem \
    --key-file=/etc/kubernetes/pki/etcd/server-key.pem \
    --peer-cert-file=/etc/kubernetes/pki/etcd/etcd-peer.pem \
    --peer-key-file=/etc/kubernetes/pki/etcd/etcd-peer-key.pem \
    --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
    --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
    --peer-client-cert-auth=true \
    --client-cert-auth=true 
```
