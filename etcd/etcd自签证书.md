### 安装cfssl

```shell
# curl -s -L -o ~/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
# curl -s -L -o ~/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
# chmod +x ~/bin/{cfssl,cfssljson}
```

### 创建CA

准备创建证书请求文件所需配置，其中应该包含CA的标识，所在主机，证书加密算法等信息；

```shell
# cat << EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "100000h"
    },  
    "profiles": {
      "server": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "100000h"
      },  
      "client": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      },  
            "peer": {
                "expiry": "8700h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]   
            }   
    }   
  }
}
EOF  

# cat << EOF > ca-csr.json 	
{
  "CN": "etcd-ca",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

# cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# cp ca.pem /etc/kubernetes/pki/etcd/
# cp ca-key.pem /etc/kubernetes/pki/etcd/
注意：*.csr 文件在整个过程中不会使用
```

- `client certificate `用于通过服务器验证客户端。例如etcdctl，etcd proxy，fleetctl或docker客户端；
- `server certificate` 由服务器使用，并由客户端验证服务器身份。例如docker服务器或kube-apiserver；
- `peer certificate` 由 etcd 集群成员使用，供它们彼此之间通信使用；
- 服务器与客户端之间的通信，这种情况下服务器的证书仅用于服务器认证，客户端证书仅用于客户端认证；
- 服务器间的通信，这种情况下每个etcd既是服务器也是客户端，因此其证书既要用于服务器认证，也要用于客户端认证；

### server certificate

修改其中CN和hosts，与创建根CA证书不同，服务器证书需要指定hosts，表明该证书可以被哪些主机使用。如果需要使用域名，主机名或者其他ip访问etcd，此处需要配置所有可能用到的域名，主机名，IP。反过来说，如果hosts列表中配置了多个节点的IP，则表示这个证书可以在多台主机上使用；将所有节点IP加入hosts列表，即整个集群可以共用这个证书；这个证书是所有节点共用的，因此需要将其拷贝到所有节点；

```shell
# cat <<EOF > server-csr.json 
{
  "CN": "kube-etcd",
  "hosts": [
    "localhost",
    "0.0.0.0",
    "127.0.0.1",
    "10.204.0.21",
    "10.204.0.37",
    "10.204.0.43"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
    }
  ]
}

# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server server-csr.json | cfssljson -bare server
# cp server.pem /etc/kubernetes/pki/etcd/
# cp server-key.pem /etc/kubernetes/pki/etcd/
```

### client certificate

```shell
# cat << EOF > client-csr.json 
{
  "CN": "etcd-client",
  "hosts": [
    ""  
  ],  
  "key": {
    "algo": "rsa",
    "size": 2048
  },  
  "names": [
    {   
    }   
  ]
}
EOF
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client-csr.json | cfssljson -bare client

# cp client.pem /etc/kubernetes/pki/etcd/
# cp client-key.pem /etc/kubernetes/pki/etcd/
```

### peer certificate

和server证书一样，3个节点的peer证书其实也可以共用一个，但是同样会带来之前提到的集群节点变化时的证书管理问题；并且集群间通信双方就是物理节点，不可能使用统一的域名或者虚拟IP，因此，好的实践是为每个节点配置自己的peer证书；

```shell
在ca所在节点通过不同胡配置文件分别创建，生成好之后拷贝到其他节点（注意要对应好）；
# cat << EOF > etcd-peer-csr.json
{
  "CN": "kube-etcd-peer",
  "hosts": [
    "k8s-dev-0-21",
    "10.204.0.21",
    "localhost",
    "127.0.0.1"
  ],  
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer etcd-peer-csr.json | cfssljson -bare etcd-peer
# cp etcd-peer.pem /etc/kubernetes/pki/etcd/
# cp etcd-peer-key.pem /etc/kubernetes/pki/etcd/
```

*将生成的密钥对拷贝到所有节点；*

```shell
# scp -r  client-key.pem client.pem server-key.pem server.pem ca-key.pem ca.pem ${IPS}:/etc/kubernetes/pki/etcd/
```

### 配置etcd

```shell
查看节点列表，获取节点标识
# ETCDCTL_API=3 etcdctl member list
1a3c142a6a5e6e84: name=k8s3 peerURLs=http://192.168.56.43:2380 clientURLs=https://192.168.56.43:2379 isLeader=false
7c1dfc5e13a8008a: name=k8s2 peerURLs=http://192.168.56.42:2380 clientURLs=https://192.168.56.42:2379 isLeader=true
c920522ba9a75e17: name=k8s1 peerURLs=http://192.168.56.41:2380 clientURLs=https://192.168.56.41:2379 isLeader=false
更新每个etcd peer url为https
# ETCDCTL_API=3 etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.pem --cert-file /etc/kubernetes/pki/etcd/client.pem --key-file /etc/kubernetes/pki/etcd/client-key.pem  member update 1a3c142a6a5e6e84 https://192.168.56.43:2380
重新检查节点列表和集群健康状态
# ETCDCTL_API=3 etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.pem --cert-file /etc/kubernetes/pki/etcd/client.pem --key-file /etc/kubernetes/pki/etcd/client-key.pem  member list 
# ETCDCTL_API=3 etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.pem --cert-file /etc/kubernetes/pki/etcd/client.pem --key-file /etc/kubernetes/pki/etcd/client-key.pem  cluster-health
此时http已改为https
修改etcd配置
挂载证书文件docker 启动参数：
	-v /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd
添加etcd启动参数：
      --cert-file=/etc/kubernetes/pki/etcd/server.pem \
      --key-file=/etc/kubernetes/pki/etcd/server-key.pem \
      --peer-cert-file=/etc/kubernetes/pki/etcd/etcd-peer.pem \
      --peer-key-file=/etc/kubernetes/pki/etcd/etcd-peer-key.pem \
      --trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
      --peer-trusted-ca-file=/etc/kubernetes/pki/etcd/ca.pem \
      --peer-client-cert-auth=true \
      --client-cert-auth=true
docker启动参数中的http改为https；
使用重启脚本依次重启etcd；
```

### apiServer使用证书连接etcd

```shell
# vim /etc/kubernetes/manifests/kube-apiserver.yaml
# 新增apiserver的启动参数
- --cert-dir=/etc/kubernetes/pki
- --etcd-cafile=/etc/kubernetes/pki/etcd/ca.pem
- --etcd-certfile=/etc/kubernetes/pki/etcd/client.pem
- --etcd-keyfile=/etc/kubernetes/pki/etcd/client-key.pem
# 修改apiserver启动参数
- --etcd-servers=https
```

#### 重启脚本

```
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
      -v /etc/kubernetes/pki/etcd:/etc/kubernetes/pki/etcd \
      -v /var/lib/etcd-cluster:/var/lib/etcd \
      k8s.gcr.io/etcd-amd64:3.3.10 etcd \
      --name="k8s-dev-0-21" \
      --initial-advertise-peer-urls=https://$currentIp:2380 \
      --listen-peer-urls=https://0.0.0.0:2380 \
      --listen-client-urls=https://0.0.0.0:2379,https://0.0.0.0:4001 \
      --advertise-client-urls=https://$currentIp:2379 \
      --initial-cluster-token=k8s-etcd-cluster \
      --initial-cluster="k8s-dev-0-21=https://10.204.0.21:2380,k8s-test-0-37=https://10.204.0.37:2380,k8s-test-0-43=https://10.204.0.43:2380" \
      --initial-cluster-state="existing" \
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

            if  $cluster = "" 
            then
                cluster="${arr[0]}=https://${arr[1]}:2380"
            else
                cluster="$cluster,${arr[0]}=https://${arr[1]}:2380"
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

```shell
# ETCDCTL_API=3 etcdctl --write-out="table" --endpoints='10.204.0.21:2379,10.204.0.43:2379,10.204.0.37:2379' endpoint status --cert=/etc/kubernetes/pki/etcd/client.pem --key=/etc/kubernetes/pki/etcd/client-key.pem  --cacert=/etc/kubernetes/pki/etcd/ca.pem

# ETCDCTL_API=3 etcdctl --endpoints='10.204.0.22:2379' endpoint status --cacert=/etc/kubernetes/pki/etcd/ca.pem --cert=/etc/kubernetes/pki/etcd/client.pem  --key=/etc/kubernetes/pki/etcd/client-key.pem
```



### Refer

[官方文档](https://coreos.com/os/docs/latest/generate-self-signed-certificates.html)

[通过etcd集群搭建了解pki安全认证-01](https://lprincewhn.github.io/2018/09/15/etcd-ha-pki-01.html)

[通过etcd集群搭建了解pki安全认证-02](http://lprincewhn.github.io/2018/10/25/etcd-ha-pki-02.html)

[etcd 启用 https](http://www.tianfeiyu.com/?p=2702)