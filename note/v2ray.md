***本文档基于CentOS 7***

**直接安装**

```shell
# bash <(curl -L -s https://install.direct/go.sh)
# vim /etc/v2ray/config.json
{
    "log": {
        "access": "/var/log/v2ray/access.log",
        "error": "/var/log/v2ray/error.log",
        "loglevel": "warning"
    },
    "inbound": {
        "port": 80,
        "protocol": "vmess",
        "settings": {
            "clients": [
                {
                    "id": "a143ccc1-ac0a-78ae-6bce-89861715d656", //UUID，可使用 cat /proc/sys/kernel/random/uuid 生成，客户端需于其保持一致；
                    "level": 1,
                    "alterId": 100
                }
            ]
        },
        "streamSettings": {
            "network": "kcp"
        },
        "detour": {
            "to": "vmess-detour-947633"
        }
    },
    "outbound": {
        "protocol": "freedom",
        "settings": {}
    },
    "inboundDetour": [
        {
            "protocol": "vmess",
            "port": "10000-10010",
            "tag": "vmess-detour-947633",
            "settings": {},
            "allocate": {
                "strategy": "random",
                "concurrency": 5,
                "refresh": 5
            },
            "streamSettings": {
                "network": "kcp"
            }
        }
    ],
    "outboundDetour": [
        {
            "protocol": "blackhole",
            "settings": {},
            "tag": "blocked"
        }
    ],
    "routing": {
        "strategy": "rules",
        "settings": {
            "rules": [
                {
                    "type": "field",
                    "ip": [
                        "0.0.0.0/8",
                        "10.0.0.0/8",
                        "100.64.0.0/10",
                        "127.0.0.0/8",
                        "169.254.0.0/16",
                        "172.16.0.0/12",
                        "192.0.0.0/24",
                        "192.0.2.0/24",
                        "192.168.0.0/16",
                        "198.18.0.0/15",
                        "198.51.100.0/24",
                        "203.0.113.0/24",
                        "::1/128",
                        "fc00::/7",
                        "fe80::/10"
                    ],
                    "outboundTag": "blocked"
                }
            ]
        }
    }
}

# systemctl start v2ray
```

**基于docker**

```shell
1、安装yum-utils，它提供了 yum-config-manager，可用来管理yum源；
	yum install -y yum-utils
2、添加docker源
	yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
3、更新索引
	yum makecache fast
4、安装 docker-ce
	yum -y install docker-ce
5、pull镜像
	docker pull v2ray/official
6、编辑配置文件 /etc/v2ray/config.json；
7、启动容器；
	docker run -dt --name v2ray -v /etc/v2ray:/etc/v2ray -p 8601:8601 --net=host v2ray/official v2ray -config=/etc/v2ray/config.json
```

**客户端配置**

```shell
{
    "log": {
        "loglevel": "warning"
    },
    "inbound": {
        "listen": "127.0.0.1",
        "port": 2048,
        "protocol": "socks",
        "settings": {
            "auth": "noauth",
            "udp": true,
            "ip": "127.0.0.1"
        }
    },
    "outbound": {
        "protocol": "vmess",
        "settings": {
            "vnext": [
                {
                    "address": "45.76.77.192",
                    "port": 80,
                    "users": [
                        {
                            "id": "a143ccc1-ac0a-78ae-6bce-89861715d656",
                            "level": 1,
                            "alterId": 100
                        }
                    ]
                }
            ]
        },
        "streamSettings": {
            "network": "kcp"
        }
    },
    "outboundDetour": [
        {
            "protocol": "freedom",
            "settings": {},
            "tag": "direct"
        }
    ],
    "routing": {
        "strategy": "rules",
        "settings": {
            "rules": [
                {
                    "type": "field",
                    "port": "54-79",
                    "outboundTag": "direct"
                },
                {
                    "type": "field",
                    "port": "81-442",
                    "outboundTag": "direct"
                },
                {
                    "type": "field",
                    "port": "444-65535",
                    "outboundTag": "direct"
                },
                {
                    "type": "field",
                    "domain": [
                        "gc.kis.scr.kaspersky-labs.com"
                    ],
                    "outboundTag": "direct"
                },
                {
                    "type": "chinasites",
                    "outboundTag": "direct"
                },
                {
                    "type": "field",
                    "ip": [
                        "0.0.0.0/8",
                        "10.0.0.0/8",
                        "100.64.0.0/10",
                        "127.0.0.0/8",
                        "169.254.0.0/16",
                        "172.16.0.0/12",
                        "192.0.0.0/24",
                        "192.0.2.0/24",
                        "192.168.0.0/16",
                        "198.18.0.0/15",
                        "198.51.100.0/24",
                        "203.0.113.0/24",
                        "::1/128",
                        "fc00::/7",
                        "fe80::/10"
                    ],
                    "outboundTag": "direct"
                },
                {
                    "type": "chinaip",
                    "outboundTag": "direct"
                }
            ]
        }
    }
}
```

refer：

[v2ray 模板，v2ray 配置生成工具](https://github.com/veekxt/v2ray-template)

