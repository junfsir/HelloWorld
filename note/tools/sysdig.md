#### 安装

自动安装

```shell
# curl -s https://s3.amazonaws.com/download.draios.com/stable/install-sysdig | sudo bash
```

手动安装

```shell
# 配置yum源
# rpm --import https://s3.amazonaws.com/download.draios.com/DRAIOS-GPG-KEY.public  
# curl -s -o /etc/yum.repos.d/draios.repo https://s3.amazonaws.com/download.draios.com/stable/rpm/draios.repo
# 安装epel仓库，以安装dkms
# yum install epel-release -y 
# 安装kernel headers
# yum -y install kernel-devel-$(uname -r) kernel-headers-$(uname -r)
# 安装sysdig
# yum -y install sysdig
```

异常处理

```shell
[root@beautiful-box-2 ~]# sysdig
Unable to load the driver
error opening device /dev/sysdig0. Make sure you have root credentials and that the sysdig-probe module is loaded.
# sysdig-probe-loader
```

https://github.com/draios/sysdig/wiki/Sysdig-Examples

https://www.oschina.net/p/sysdig