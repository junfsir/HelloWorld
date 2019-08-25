### 升级内核版本(bbr拥塞算法对内核版本有一定要求)

```shell
# rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
# rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
# yum --enablerepo=elrepo-kernel install kernel-ml -y

# rpm -qa|grep kernel
# egrep ^menuentry /etc/grub2.cfg | cut -f 2 -d \'
# grub2-set-default 0
# reboot
```

### 安装docker

```shell
# yum install -y yum-utils
# yum-config-manager     --add-repo     https://download.docker.com/linux/centos/docker-ce.repo
# yum-config-manager --enable docker-ce-edge
# yum install -y docker-ce
```

### 开启bbr拥塞算法

```shell
# echo 'net.core.default_qdisc=fq' | sudo tee -a /etc/sysctl.conf
# echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.conf
# sysctl -p
# sysctl net.ipv4.tcp_available_congestion_control
# sysctl -n net.ipv4.tcp_congestion_control
# lsmod | grep bbr
# systemctl start docker
# systemctl enable docker
```

### 部署ss服务

```shell
# docker run -dt --restart=always --name ssserver -p 443:443 mritd/shadowsocks -s "-s 0.0.0.0 -p 443 -m aes-256-cfb -k jeason_123*& --fast-open"
```

