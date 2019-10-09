- ping

```shell
ansible k8s -m ping
```

- file

```shell
ansible k8s -m file -a "path=/svc/thsft/cache/newsservice/smarty/templates_c/news-push state=directory owner=jgb group=jgb mode=0777"
```

- shell(raw和command、shell类似，但是它可以传递管道)

```shell
ansible k8s -m shell -a "cat cat /var/log/hxcs/udata/udata.log.2018-01-0* |grep 83317031"
```

- yum

```shell
ansible k8s -m yum -a "name=libvirt"
```

- service

```shell
ansible k8s -m service  -a "name=libvirtd state=started"
```

- copy

```shell
ansible k8s -m copy -a "src=profile dest=/etc/profile backup=yes"
```

- group

```shell
ansible k8s -m group -a "name=jgb state=present gid=1002" -become
```

- user

```shell
ansible k8s -m user -a "name=jgb state=present uid=1002 group=jgb" -become
```

- lineinfile

```shell
ansible k8s -m lineinfile -a "dest=/etc/cron.d/cron_ops line='0 */2 * * * root /bin/bash /usr/local/bin/diagnose_orphanpod.sh &> /data/top/diagnose_orphanpod.log'"
```

- script(本地写脚本，远程执行)

```shell
ansible k8s -m script -a "bash /tmp/test.sh" 
```

- 排除某个节点

```shell
ansible k8s_product:\!10.200.0.191 -m shell -a "grep '/var/lib' /usr/local/nagios/libexec/check_kubelet_cert_expired.sh"
```

- plugin帮助

```shell
ansible-doc -s yum
ansible-doc -l
```

