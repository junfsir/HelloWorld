Kubernetes集群一直存在着node上某个业务pod的IO操作较频繁，而导致整个node的负载异常，影响其上的所有业务。调研了社区里的方案，可基于cgroup的blkio来实现对IO的限制，但是cgroupv1无法追踪异步io，可行度不高。所以可采用cgroupv2，其增加了对异步IO的追踪支持，简述方案：

1. 升级内核

cgroupv2从某些固定内核版本开始支持，所以需升级到指定的版本，但是还存在一个问题，就是所选择内核版本的性能如何。当前集群使用的内核版本是4.4.147，性能极佳，为了支持cgroupv2，测试了4.14和4.19的内核，由于CPU漏洞内核补丁及其他一系列原因，结果不尽如意。又测试了CentOS 8，其性能是和4.14最接近，但是对iptables的支持摒弃了老的内核子系统，导致kube-proxy无法使用，需切换到ipvs模式。然而，切换之后，kube-proxy的CPU使用率升高了十几倍，再次搁浅；

```shell
# 升级内核之后还需要升级docker和containd的版本，来支持cgroupv1和v2 mixed（v1 cpu和mem，v2 io）
rpm -Uvh  docker-ce-cli-18.09.4-3.el7.x86_64.rpm  docker-ce-18.09.4-3.el7.x86_64.rpm containerd.io-1.2.5-3.1.el7.x86_64.rpm

# 修改默认grub参数以支持cgroup mixed 
# cat /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet cgroup_no_v1=io LANG=zh_CN.UTF-8 vsyscall=emulate  noibrs noibpb nopti nospectre_v2 nospectre_v1 l1tf=off nospec_store_bypass_disable no_stf_barrier mds=off"
GRUB_DISABLE_RECOVERY="true"

# 生成新的配置
grub2-mkconfig -o /etc/grub2.cfg 
grub2-mkconfig -o /boot/grub2/grub.cfg

# 修改默认启动内核

# 查看默认启动顺序
awk -F\' '$1=="menuentry " {print $2}' /etc/grub2.cfg
CentOS Linux (4.4.147-1.el7.elrepo.x86_64) 7 (Core)
CentOS Linux (3.10.0-514.el7.x86_64) 7 (Core)
CentOS Linux (0-rescue-7b8043d46dd64c3a953da9c372358d2f) 7 (Core)

# 默认启动的顺序是从0开始，但我们新内核是从头插入（目前位置在0，而3.10的是在1），所以需要选择0，如果想生效最新的内核，需要
grub2-set-default 0

reboot
```

2. 创建并挂载cgroupv2的相关dir

```shell
# append to /etc/rc.local
CGROUP2MOUNTPOINT="/cgroupv2"
BLKIOCG=`mount |grep cgroup |grep blkio |wc -l`
IOCGV2=`mount|grep cgroup2|wc -l`
if [ ! -d "/cgroupv2" ]; then
    mkdir $CGROUP2MOUNTPOINT
else
    echo "cgroup2 mount point exists"
fi
if [ $BLKIOCG -eq 0 ]
then
    if [ $IOCGV2 -eq 0 ];then
         mount -t cgroup2 nodev /cgroupv2
    else
        echo "cgroup2 already mount"
    fi
    if [ `cat $CGROUP2MOUNTPOINT/cgroup.subtree_control|wc -l` -ne 1 ];then
        echo "+io" > /cgroupv2/cgroup.subtree_control
    else
        echo "io subsystem have been added to cgroup.subtree_control"
    fi
else
    echo "use cgroup blkio v1"
fi
```

3. 实现一个agent，基于可配置平台来动态修改cgroup，限制IO