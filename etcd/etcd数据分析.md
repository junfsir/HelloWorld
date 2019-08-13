#### 获取ETCD中的所有数据

```shell
# --prefix 表示获取所有key值头为某个字符串的数据， 由于传入的是""，所以会匹配所有的值
# --keys-only 表示只返回key而不返回value
```

####  对输出的结果使用grep过滤掉空行

```shell
# ETCDCTL_API=3 etcdctl --endpoints='http://10.204.0.31:2379' get "" --prefix --keys-only |grep -Ev "^$"

# 输出结果如下所示，实际数据会非常整齐
/registry/apiextensions.k8s.io/customresourcedefinitions/globalbgpconfigs.crd.projectcalico.org
/registry/apiextensions.k8s.io/customresourcedefinitions/globalfelixconfigs.crd.projectcalico.org
/registry/apiextensions.k8s.io/customresourcedefinitions/globalnetworkpolicies.crd.projectcalico.org
# ... 略过很多条目
/registry/namespaces/default
/registry/namespaces/kube-public
/registry/namespaces/kube-system
/registry/pods/kube-system/canal-mljsv
/registry/pods/kube-system/canal-qlvh6
# ... 略过很多条目
/registry/services/endpoints/kube-system/kube-scheduler
/registry/services/specs/default/kubernetes
/registry/services/specs/kube-system/kube-dns
compact_rev_key
```

#### ETCD中key值的规律
`kubernetes`主要把自己的数据注册在`/registry/`前缀下面（在`ETCD-v3`版本后没有了目录的概念，一切皆前缀）；
通过观察k8s中`deployment`、`namespace`、`pod`等在`ETCD`中的表示，可以知道这部分资源的key的格式为`/registry/#{k8s对象}/#{命名空间}/#{具体实例名}`；
存在一个与众不同的key值`compact_rev_key`，搜索可以知道这是`apiserver/compact.go`中用来记录无效数据版本使用的，运行etcdctl get compact_rev_key可以发现，输出的是一个整形数值；

#### ETCD保存的是Protocol Buffers（Protobuf）序列化后的值

```shell
# 获取"/registry/ranges/serviceips"所对应的值
# 发现这里有很多奇怪的字符=。=
# 可以大体推断出来，集群所有service的ip范围为10.96.0.0/12， 与api-server的yaml文件中配置的一致
# etcdctl get /registry/ranges/serviceips
/registry/ranges/serviceips
k8s

v1RangeAllocation&

"*28Bz
      10.96.0.0/12"

# 获取"/registry/services/endpoints/default/kubernetes"所对应的值
# 发现这里有很多奇怪的字符=。=
# 在default命名空间的kubernetes这个service所对应的endpoint有两个ip
# 分别为192.168.205.137和192.168.205.139
/$ etcdctl get /registry/services/endpoints/default/kubernetes
/registry/services/endpoints/default/kubernetes
k8s

v1	Endpoints�
O

kubernetesdefault"*$0b6bb724-f066-11e8-be14-000c29d2cb3a2ں��z;

192.168.205.137

192.168.205.139
https�2TCP"
```

------

`Kubenretes1.6`中使用etcd V3版本的API，使用`etcdctl`直接`ls`的话只能看到`/kube-centos`一个路径。需要在命令前加上`ETCDCTL_API=3`这个环境变量才能看到kuberentes在etcd中保存的数据。

```
ETCDCTL_API=3 etcdctl get /registry/namespaces/default -w=json|python -m json.tool
```

如果是使用 kubeadm 创建的集群，在 Kubenretes 1.11 中，etcd 默认使用 tls ，这时你可以在 master 节点上使用以下命令来访问 etcd ：

```
ETCDCTL_API=3 etcdctl --cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/peer.crt \
--key=/etc/kubernetes/pki/etcd/peer.key \
get /registry/namespaces/default -w=json | jq .
```

- `-w`指定输出格式

将得到这样的json的结果：

```
{
    "count": 1,
    "header": {
        "cluster_id": 12091028579527406772,
        "member_id": 16557816780141026208,
        "raft_term": 36,
        "revision": 29253467
    },
    "kvs": [
        {
            "create_revision": 5,
            "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMvZGVmYXVsdA==",
            "mod_revision": 5,
            "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEmIKSAoHZGVmYXVsdBIAGgAiACokZTU2YzMzMDgtMWVhOC0xMWU3LThjZDctZjRlOWQ0OWY4ZWQwMgA4AEILCIn4sscFEKOg9xd6ABIMCgprdWJlcm5ldGVzGggKBkFjdGl2ZRoAIgA=",
            "version": 1
        }
    ]
}
```

使用`--prefix`可以看到所有的子目录，如查看集群中的namespace：

```
ETCDCTL_API=3 etcdctl get /registry/namespaces --prefix -w=json|python -m json.tool
```

输出结果中可以看到所有的namespace。

```
{
    "count": 8,
    "header": {
        "cluster_id": 12091028579527406772,
        "member_id": 16557816780141026208,
        "raft_term": 36,
        "revision": 29253722
    },
    "kvs": [
        {
            "create_revision": 24310883,
            "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMvYXV0b21vZGVs",
            "mod_revision": 24310883,
            "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEmQKSgoJYXV0b21vZGVsEgAaACIAKiQ1MjczOTU1ZC1iMzEyLTExZTctOTcwYy1mNGU5ZDQ5ZjhlZDAyADgAQgsI7fSWzwUQ6Jv1Z3oAEgwKCmt1YmVybmV0ZXMaCAoGQWN0aXZlGgAiAA==",
            "version": 1
        },
		...
        {
            "create_revision": 15212191,
            "key": "L3JlZ2lzdHJ5L25hbWVzcGFjZXMveWFybi1jbHVzdGVy",
            "mod_revision": 15212191,
            "value": "azhzAAoPCgJ2MRIJTmFtZXNwYWNlEn0KYwoMeWFybi1jbHVzdGVyEgAaACIAKiQ2YWNhNjk1Yi03N2Y5LTExZTctYmZiZC04YWYxZTNhN2M1YmQyADgAQgsI1qiKzAUQkoqxDloUCgRuYW1lEgx5YXJuLWNsdXN0ZXJ6ABIMCgprdWJlcm5ldGVzGggKBkFjdGl2ZRoAIgA=",
            "version": 1
        }
    ]
}
```

key的值是经过base64编码，需要解码后才能看到实际值，如：

```
# echo L3JlZ2lzdHJ5L25hbWVzcGFjZXMvYXV0b21vZGVs|base64 -d
/registry/namespaces/automodel
```

#### etcd中kubernetes的元数据

我们使用kubectl命令获取的kubernetes的对象状态实际上是保存在etcd中的，使用下面的脚本可以获取etcd中的所有kubernetes对象的key：

> 注意，我们使用了ETCD v3版本的客户端命令来访问etcd。

```
#!/bin/bash
# Get kubernetes keys from etcd
export ETCDCTL_API=3
keys=`etcdctl get /registry --prefix -w json|python -m json.tool|grep key|cut -d ":" -f2|tr -d '"'|tr -d ","`
for x in $keys;do
  echo $x|base64 -d|sort
done
```

通过输出的结果我们可以看到kubernetes的原数据是按何种结构包括在kuberentes中的，输出结果如下所示：

```
/registry/ThirdPartyResourceData/istio.io/istioconfigs/default/route-rule-details-default
/registry/ThirdPartyResourceData/istio.io/istioconfigs/default/route-rule-productpage-default
/registry/ThirdPartyResourceData/istio.io/istioconfigs/default/route-rule-ratings-default
...
/registry/configmaps/default/namerctl-script
/registry/configmaps/default/namerd-config
/registry/configmaps/default/nginx-config
...
/registry/deployments/default/sdmk-page-sdmk
/registry/deployments/default/sdmk-payment-web
/registry/deployments/default/sdmk-report
...
```

我们可以看到所有的Kuberentes的所有元数据都保存在`/registry`目录下，下一层就是API对象类型（复数形式），再下一层是`namespace`，最后一层是对象的名字。