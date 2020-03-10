## [Raspberry Pi 3B+ 安装 OpenWrt 和 v2ray](https://blog.smalljiejie.com/post/raspberry-pi-3ban-zhuang-openwrt-he-v2ray/)

使用树莓派3B+安装openWRT存在诸多陷阱，本文旨在使用树莓派3B+快速安装openWRT并指出其中存在的诸多问题。

# 准备工作

## 1 所需设备

树莓派、网线、内存卡、读卡器。

## 2 镜像下载

前往[openWRT最新开发版](https://downloads.openwrt.org/snapshots/targets/brcm2708/bcm2710/)下载最新的开发版镜像，**不要使用稳定版镜像安装**，稳定版镜像无法正常开机。

## 3 镜像烧写

推荐使用[Etcher](https://www.balena.io/etcher/)进行烧写，选择所下载的镜像、准备使用的内存卡，Flash即可。

# 设置方法

方案1：网线直连树莓派和电脑
方案2：连接键盘和显示器

## 1 修改网络设置

1. 使用`passwd`命令修改设备密码
2. 编辑/etc/config/network文件

```shell
config interface 'loopback'
	option ifname 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'
config globals 'globals'
	option ula_prefix 'fda0:8c6e:a39a::/48'
config interface 'lan'
	option type 'bridge'
	option proto 'static'
	option ipaddr '192.168.11.1'
	option netmask '255.255.255.0'
	option ip6assign '60'
config interface 'wan'
	option proto 'dhcp'
	option ifname 'eth0'
```

使用DHCP连接上一级路由，使用192.168.11.1作为局域网地址。
***不推荐使用Luci进行本部分设置，可能无法保存***

3. 编辑/etc/config/wireless文件

```shell
config wifi-device 'radio0'
	option type 'mac80211'
	option channel '36'
	option hwmode '11a'
	option path 'platform/soc/3f300000.mmcnr/mmc_host/mmc1/mmc1:0001/mmc1:0001:1'
	option htmode 'VHT80'
	option disabled '0'
	option country '00'
	option legacy_rates '1' #此处需要由0改为1
config wifi-iface 'default_radio0'
	option device 'radio0'
	option network 'lan'
	option mode 'ap'
	option ssid 'OpenWrt' #WiFi名称
	option encryption 'psk-mixed'
	option key 'xxxxxxxx' #WiFi密码
```

开启WiFI并设置密码。
修改完成后将路由器连接至上一级路由器即可作为二级无线路由使用。

## 2 安装Luci

1. 连接至树莓派的WiFi网络，并登录

```shell
ssh root@192.168.11.1
```

1. 更新opkg软件列表安装Luci及其中文包

```shell
opkg update
opkg install luci
opkg install luci-i18n-base-zh-cn
```

安装完成后即可使用浏览器登录openWRT的管理界面。

## 3 安装v2ray

1. 下载[v2ray-arm64最新版](https://github.com/v2ray/v2ray-core/releases/download/v4.20.0/v2ray-linux-arm64.zip)并解压，将其中的`v2ctl`，`v2ray`，`geoip.dat`，`geosite.dat`上传至树莓派的`/usr/bin/`目录下

```shell
scp v2ctl root@192.168.11.1:/usr/bin/
scp v2ray root@192.168.11.1:/usr/bin/
scp geoip.dat root@192.168.11.1:/usr/bin/
scp geosite.dat root@192.168.11.1:/usr/bin/
```

1. 登陆树莓派并给`v2ctl`，`v2ray`可执行权限

```shell 
chmod +x /usr/bin/v2ctl
chmod +x /usr/bin/v2ray
```

1. 在`/etc/init.d/`中新建`v2ray`文件，创建v2ray服务

```shell
#!/bin/sh /etc/rc.common
START=90
USE_PROCD=1
start_service() {
        mkdir /var/log/v2ray > /dev/null 2>&1
        procd_open_instance
        procd_set_param respawn
        procd_set_param command /usr/bin/v2ray/v2ray -config /etc/v2ray/config.json
        procd_set_param file /etc/v2ray/config.json
        procd_set_param stdout 1
        procd_set_param stderr 1
        procd_set_param pidfile /var/run/v2ray.pid
        procd_close_instance
}
```

使v2ray开机启动

```shell
/etc/init.d/v2ray enable
```

1. 在`/etc/v2ray/`目录中创建v2ray配置文件`config.json`
   该部分本文不赘述，可参考[v2ray官方网站](https://www.v2ray.com/)
2. 启动v2ray

```shell
service v2ray start
```

## 4 配置防火墙

登录openWRT管理页，并在防火墙中设置用户规则

```shell
iptables -t nat -N V2RAY
iptables -t nat -A V2RAY -d XX.XX.XX.XX -j RETURN #服务器IP
iptables -t nat -A V2RAY -d 0.0.0.0/8 -j RETURN
iptables -t nat -A V2RAY -d 10.0.0.0/8 -j RETURN
iptables -t nat -A V2RAY -d 127.0.0.0/8 -j RETURN
iptables -t nat -A V2RAY -d 169.254.0.0/16 -j RETURN
iptables -t nat -A V2RAY -d 172.16.0.0/12 -j RETURN
iptables -t nat -A V2RAY -d 192.168.0.0/16 -j RETURN
iptables -t nat -A V2RAY -d 224.0.0.0/4 -j RETURN
iptables -t nat -A V2RAY -d 240.0.0.0/4 -j RETURN
iptables -t nat -A V2RAY -p tcp -j REDIRECT --to-ports 1060 #代理服务的端口号
iptables -t nat -A PREROUTING -p tcp -j V2RAY
```

该规则将除局域网内的所有流量转发至代理端口，端口号请根据需要自行修改，修改完成后重启防火墙。

# 其他事项

## 关于GWF的说明

网上其他教程有使用dnsmasq配合gwflist做黑名单代理的方案，本文不做推荐，如果需要做按需代理请在v2ray配置文件中使用`routing`进行分流，dnsmasq转发DNS请求会使得部分使用**IP**直接连接的软件无法通过GWF，虽然可以通过ipset解决，但是过于繁琐。
此外，如果决定使用dnsmasq进行分流，你需要安装dnsmasq-full，此处需要注意，**请先下载dnsmasq-full的安装包然后卸载dnsmasq**，然后使用ipk包安装dnsmasq-full！