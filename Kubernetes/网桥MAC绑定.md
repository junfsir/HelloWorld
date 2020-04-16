公司在网络层对服务器`IP`和`MAC`的对应关系，有相关监控；某天发现，某些`kubernetes node`的`IP`对应的`MAC`经常变化，且有时候会出现访问某些节点`IP`不通的情况；后查明，在桥接模式下，网桥`br0`的`MAC`是从其所有桥接中选一个`MAC`最小的地址广播出去；那么在`Pod create`异常的情况下，其`MAC`就会根据`cni`插件的规范，一直生成新的`MAC`，遂有此现象。

#### 现象重现

```shell
# vim test.sh 
set -xe
ifconfig br0
# 新增虚拟网卡对
ip link add vethtest1 type veth peer name vethtest2
ifconfig vethtest1 hw ether $1
ip link set vethtest1 master br0
ifconfig br0
ip link delete vethtest1 type veth peer name vethtest2
ifconfig br0
```

```shell
# mac地址使用小于当前br0使用的地址即可重现现象
# sh test.sh 00:0d:6e:66:6f:be
```

#### bind br0 hw

```shell
# vim bind_hw.sh
set -xe
hw=`ip addr|grep 'master br0'|grep -v veth|awk -F ': ' '{print $2}'|head -1|xargs ifconfig|grep ether|awk '{print $2}'`
ip=`ifconfig br0|grep 'inet '|awk '{print $2}'`
ifconfig br0 hw ether $hw
#首次启动才需要，避免不必要的重启广播
#arping -U -I br0 $ip -c 3
```

#### refer

[Linux bridge: MAC addresses and dynamic ports](https://backreference.org/2010/07/28/linux-bridge-mac-addresses-and-dynamic-ports/)

