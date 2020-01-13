### IPVS 替换 Iptables

编辑 kube-proxy 的配置，将mode配置为ipvs；

```shell
# kubectl edit cm kube-proxy  -nkube-system
```

各节点安装ipset , ipvsadm；

确保内核加载了ipvs模块；

```shell
# lsmod|grep ip_vs
ip_vs_sh               12688  0
ip_vs_wrr              12697  0
ip_vs_rr               12600  16
ip_vs                 141092  23 ip_vs_rr,ip_vs_sh,xt_ipvs,ip_vs_wrr
nf_conntrack          133387  9 ip_vs,nf_nat,nf_nat_ipv4,nf_nat_ipv6,xt_conntrack,nf_nat_masquerade_ipv4,nf_conntrack_netlink,nf_conntrack_ipv4,nf_conntrack_ipv6
libcrc32c              12644  3 ip_vs,nf_nat,nf_conntrack
```

若未加载ipvs则执行以下命令；

```shell
# modprobe -- ip_vs
# modprobe -- ip_vs_rr
# modprobe -- ip_vs_wrr
# modprobe -- ip_vs_sh
# modprobe -- nf_conntrack_ipv4
重新启动kube-proxy pod ，如果ipvs替换成功可以看到这样的日志。
I0712 10:43:17.243529       1 server_others.go:183] Using ipvs Proxier.
W0712 10:43:17.265349       1 proxier.go:304] IPVS scheduler not specified, use rr by default
```

### iptable切换到ipvs后iptables规则的变化

```shell
1.nat表
Chain KUBE-SVC-* 没有了  #服务规则
Chain KUBE-SEP-* 没有了
每个Service的每个服务端口都会在Chain KUBE-SERVICES中有一条对应的规则，发送到clusterIP的报文，将会转发到对应的Service的规则链，没有命中ClusterIP的，转发到KUBE-NODEPORTS。最后在KUBE-SEP-XX中完整了最终的DNAT，将目的地址转换成了POD的IP和端口。
2.raw表
少了Chain PREROUTING 
   Chain OUTPUT
3.filter表
无变化 
4.security 、mangle表
切换前后都是空的，无变化 
5.IPVS 用于负载均衡，它无法处理 kube-proxy 中的其他问题，例如 包过滤，数据包欺骗，SNAT 等
IPVS proxier 在上述场景中利用 iptables。 具体来说，ipvs proxier 将在以下4种情况下依赖于 iptables：
kube-proxy 以 –masquerade-all = true 开头
在 kube-proxy 启动中指定集群 CIDR
支持 Loadbalancer 类型服务
支持 NodePort 类型的服务
```

### ipvs 配置均衡策略

```shell
kubectl edit cm kube-proxy -nkube-system
data.config.conf.ipvs.scheduler: "rr"
```

### ipvs sessionAffinity 测试

```
将service的spec.sessionAffinity: ClientIP(默认为None），源IP相同的请求会发到相同的pod上。
测试思路： 创建一个k8s-taint pod，my-servie service后端用nginx pod，在k8s-taint中请求curl my-service-CluseterIP,在k8s-taint pod的宿主机上tcpdump抓包，观察回应请求的IP.
以下是测试结果中两次的数据：
14:50:30.247528 IP 10.205.197.219.58190 > yfb-0-137.http: Flags [F.], seq 78, ack 852, win 62, options [nop,nop,TS val 708413646 ecr 2510167615], length 0
14:50:30.247697 IP 10.205.213.170.http > 10.205.197.219.58190: Flags [F.], seq 852, ack 79, win 57, options [nop,nop,TS val 2510167615 ecr 708413646], length 0
14:50:30.247720 IP yfb-0-137.http > 10.205.197.219.58190: Flags [F.], seq 852, ack 79, win 57, options [nop,nop,TS val 2510167615 ecr 708413646], length 0
14:50:30.247736 IP 10.205.197.219.58190 > yfb-0-137.http: Flags [.], ack 853, win 62, options [nop,nop,TS val 708413646 ecr 2510167615], length 0
14:50:30.247766 IP 10.205.197.219.58190 > yfb-0-137.http: Flags [.], ack 853, win 62, options [nop,nop,TS val 708413646 ecr 2510167615], length 0
14:50:30.247937 IP 10.205.213.170.http > 10.205.197.219.58190: Flags [R], seq 354069092, win 0, length 0
14:50:30.247966 IP yfb-0-137.http > 10.205.197.219.58190: Flags [R], seq 354069092, win 0, length 0
```

refer：

 https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs 

https://kubernetes.io/blog/2018/07/09/ipvs-based-in-cluster-load-balancing-deep-dive/