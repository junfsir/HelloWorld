###　CentOS8安装Kubernetes

做桥接（pod为bridge网络模型）；

```shell
# 通过修改配置文件来做桥接，需要提前安装network-scripts
# yum install network-scripts -y
# systemctl restart network
```

安装docker；

```shell
# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
# yum list docker-ce --showduplicates | sort -r
# yum install https://download.docker.com/linux/fedora/30/x86_64/stable/Packages/containerd.io-1.2.6-3.3.fc30.x86_64.rpm
# yum remove podman
# yum install docker-ce-3:18.09.4-3.el7
```

安装kubelet；

```shell
# cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
# yum install kubeadm-1.12.9-0 kubelet-1.12.9-0
```

同步时间；

```shell
# systemctl start chronyd
# systemctl enable chronyd
```

join集群；

```shell
# kubeadm join xxx --ignore-preflight-errors=cri --ignore-preflight-errors=SystemVerification
```

以下模块默认没有加载；

```shell
# modprobe -- ip_vs
# modprobe -- ip_vs_rr
# modprobe -- ip_vs_wrr
# modprobe -- ip_vs_sh
# modprobe -- nf_conntrack_ipv4
# modprobe -- ip_tables
```

问题；

```shell
基于iptables的kube-proxy不兼容，新版本内核子模块做了修改；
```



```shell
https://www.tigera.io/blog/comparing-kube-proxy-modes-iptables-or-ipvs/

https://kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# modprobe ip_tables
https://stackoverflow.com/questions/21983554/iptables-v1-4-14-cant-initialize-iptables-table-nat-table-does-not-exist-d/27129275

# kubectl -n kube-system exec -i kube-proxy-gz57m -- /bin/sh -c "iptables -t nat -N KUBE-MARK-DROP;iptables -t nat -A KUBE-MARK-DROP -j MARK --set-xmark 0x8000/0x8000"
https://github.com/kubernetes/kubernetes/issues/80462
```

```shell
https://blog.tianfeiyu.com/2019/11/18/kube_proxy_ipvs/
https://blog.tianfeiyu.com/2019/11/06/kube_proxy_iptables/
```

