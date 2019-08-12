我们线上使用的集群版本是`v1.10.5`，随着业务量的接入，`iptables`逐渐到了瓶颈，需进行升级。此问题是出现在升级过程中，`spec hash changed, and container recreate`。

```shell
Even though Kubernetes already support 5000 nodes in release v1.6, the kube-proxy with iptables is actually a bottleneck to scale the cluster to 5000 nodes. One example is that with NodePort Service in a 5000-node cluster, if we have 2000 services and each services have 10 pods, this will cause at least 20000 iptable records on each worker node, and this can make the kernel pretty busy.
```

`hash spec changed`原因：

`kubelet`会为容器计算一个`hash`值，然后用容器的名称去查询对应`docker`容器的`hash`值；若查找到容器，且二者的`hash`值不同，则停止`docker`中容器的进程，并停止与之关联的`pause`容器的进程；若二者相同，则不做任何处理；

解决方案：

1. 加一个`annotation`代表`hash`的版本，用`v1.10`或者`v1.12`的，这个是创建的时候决定的，另外注意各个组件的`client-go`版本一致性；
2. `evict pod`，时间不好把控，有的`pod`最好不要`recreate`；

```shell
# kubectl drain --delete-local-data --ignore-daemonsets $NODE
```



refer：

[IPVS-Based In-Cluster Load Balancing Deep Dive](https://kubernetes.io/blog/2018/07/09/ipvs-based-in-cluster-load-balancing-deep-dive/)

[Kubelet从1.7.16升级到1.9.11，Sandbox以外的容器都被重建的问题调查](https://www.lijiaocn.com/%E9%97%AE%E9%A2%98/2019/01/14/kubelet-updates-container-restart.html)

[Upgrade kubelet from v1.11.3 to v.12.3 without draining pods causes containers to restart continuously](https://github.com/kubernetes/kubernetes/issues/72296)
