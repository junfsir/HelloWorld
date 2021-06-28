> 环境：百度专有云/openshift4
>
> 南北流量：dns --> blb --> route

问题描述：

`login`正常，`pull`正常，`push`出现如下错误：

> unauthorized: unauthorized to access repository: public/alpine, action: push: unauthorized to access repository: public/alpine, action: push

解决：

1、If Harbor is running behind an `nginx` proxy or elastic load balancing, open the file `common/config/nginx/nginx.conf` and search for the following line.

```fallback
proxy_set_header X-Forwarded-Proto $scheme;
```

If the proxy already has similar settings, remove it from the sections `location /`, `location /v2/` and `location /service/` and redeploy Harbor. 

[from](https://goharbor.io/docs/2.2.0/install-config/troubleshoot-installation/#using-nginx-or-load-balancing)

2、移除配置重启后，`push`报错

> unknown blob

根据官方`issues`，修改`registry`配置为：

> relativeurls: true

