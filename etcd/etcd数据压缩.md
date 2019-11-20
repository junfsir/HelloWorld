# [etcd 问题汇总]( https://github.com/nutscloud/learning/issues/4 )

## mvcc: database space exceeded解决

### 原因分析

- etcd服务未设置自动压缩参数（auto-compact）
- etcd 默认不会自动 compact，需要设置启动参数，或者通过命令进行compact，如果变更频繁建议设置，否则会导致空间和内存的浪费以及错误。Etcd v3 的默认的 backend quota 2GB，如果不 compact，boltdb 文件大小超过这个限制后，就会报错：”Error: etcdserver: mvcc: database space exceeded”，导致数据无法写入。

### 处理过程

- 确认是否超出配额：`ETCDCTL_API=3 etcdctl --write-out=table endpoint status`
- 查看告警：`ETCDCTL_API=3 etcdctl alarm list`
- 设置etcd配额：etcd --quota-backend-bytes=$((8*1024*1024*1024))
- 获取当前etcd数据的修订版本(revision)：`rev=$(ETCDCTL_API=3 etcdctl endpoint status --write-out="json" | egrep -o '"revision":[0-9]*' | egrep -o '[0-9]*')`
- 整合压缩旧版本数据：`ETCDCTL_API=3 etcdctl compact $rev`
- 执行碎片整理：`ETCDCTL_API=3 etcdctl defrag`
- 解除告警：`ETCDCTL_API=3 etcdctl alarm disarm`
- 备份以及查看备份数据信息：

```
ETCDCTL_API=3 etcdctl snapshot save backup.db
ETCDCTL_API=3 etcdctl snapshot status backup.db
```

## etcd 优化

1. --auto-compaction-retention
   由于ETCD数据存储多版本数据，随着写入的主键增加历史版本需要定时清理， 默认的历史数据是不会清理的，数据达到2G就不能写入，必须要清理压缩历史数据才能继续写入；所以根据业务需求，在上生产环境之前就提前确定，历史数据多长时间压缩一次；推荐一小时压缩一次数据。这样可以极大的保证集群稳定，减少内存和磁盘占用
2. --max-request-bytes
   etcd Raft 消息最大字节数，ETCD 默认该值为1.5M; 但是很多业务场景发现同步数据的时候1.5M完全没法满足要求，所以提前确定初始值很重要；由于1.5M导致我们线上的业务无法写入元数据的问题，我们紧急升级之后把该值修改为默认32M,但是官方推荐的是10M，大家可以根据业务情况自己调整
3. --quota-backend-bytes
   ETCD db 数据大小，默认是 2G,当数据达到 2G的时候就不允许写入，必须对历史数据进行压缩才能继续写入； 参加1里面说的，我们启动的时候就应该提前确定大小，官方推荐是8G,这里我们也使用8G的配置

---

# [etcd 之坑]( https://drafts.damnever.com/2018/the-hole-in-etcd.html )

---

# [ETCD数据压缩]( https://www.rancher.cn/docs/rancher/v2.x/cn/configuration/admin-settings/compact/ )

