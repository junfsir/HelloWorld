## harbor组件：

### harbor架构

![harbor架构](https://img-blog.csdn.net/20180321084347144?watermark/2/text/Ly9ibG9nLmNzZG4ubmV0L2xpdWt1YW43Mw==/font/5a6L5L2T/fontsize/400/fill/I0JBQkFCMA==/dissolve/70)

### stateless components：

> * jobservice
> * nginx
> * ui
> * registry
> * adminserver
> * log

### stateful components：
> * db
> * redis
> * clair

### harbor ha 架构

> * 部署两个harbor实例运行Adminserver、UI、Proxy、Log Collector、Registry、Jobservice这5个stateless components；
> * 前端用keepalived高可用入口VIP；
> * 数据库用一套，通过高可用集群方式保障数据高可用；
> * 多个registry的后端使用同一块共享存储；
> * 多个UI使用同一个redis共享session；

![Architecture.png](https://github.com/goharbor/harbor/blob/release-1.6.0/docs/img/ha/Architecture.png?raw=true)



### 硬件资源  

8 cores & 16 GB * 2：两个节点上既部署harbor实例，同时部署redis主从和PostgreSQL主从，皆使用container的方式；

## 部署

### 准备

- [x] PostgreSQL image && PostgreSQL  == 9.6.10
- [x] harbor1.6离线包

- [x] redis-server image && redis-server == 4.0.10

------

###  1. 搭建redis集群

``` shell
docker pull redis:4.0.10
```

``` yaml
version: '2'
services:		
  redis:
    image: redis:4.0.10
    container_name: redis-db
    restart: always
    network_mode: "host"
    ports:
      - 6379:6379
    volumes:
      - /data/redis:/var/lib/redis
	  - /etc/localtime:/etc/localtime:ro
	  - /data2/redis.conf:/usr/local/bin/redis.conf
	command: ["/usr/local/bin/redis-server","/usr/local/bin/redis.conf"]

```

``` shell
redis.conf
bind 0.0.0.0
protected-mode no
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile "/tmp/redis_6379.pid"
loglevel notice
databases 16
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename "dump.rdb"
dir "/var/lib/redis"
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slave-priority 100
requirepass "password"
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events ""
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-size -2
list-compress-depth 0
set-max-intset-entries 512
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
aof-rewrite-incremental-fsync yes
```



------

### 2. 搭建共享存储

**可选方案**

- [x] 直接使用nfs，做主备；

``` shell
yum install nfs-utils rpcbind  -y
 systemctl restart rpcbind   
 systemctl start nfs  
 vim /etc/exports 
 /shared 192.168.0.0/16(rw,no_root_squash,no_all_squash,async)
 exportfs -r

showmount -e 192.168.216.126

mount -t nfs 192.168.216.126:/shared /shared
```

- [x] 镜像备份基于rsync + inotify 或者 lsyncd + rsync

```shell
在文件源服务器和目标服务器安装rsync，并在源服务器安装lsyncd，需配置epel源；
配置源服务器到目标服务器的root免密登录；
编辑配置：
vim /etc/lsyncd.conf
settings {
    logfile ="/var/log/lsyncd/lsyncd.log",
    statusFile ="/var/log/lsyncd/lsyncd.status",
    inotifyMode = "CloseWrite",
    maxProcesses = 8,
    }
sync {
    default.rsync,
    source    = "/shared/registry/",
    target    = "root@192.168.216.113:/nfsbak/registry/",
    maxDelays = 5,
    delay = 30,
    -- init = true,
    delete = 'running',
    rsync     = {
        binary = "/usr/bin/rsync",
        archive = true,
        compress = true,
        bwlimit   = 40960
        }
    }
启动服务：
systemctl start lsyncd
```



```shell
# 在/proc/sys/fs/inotify目录下有三个文件，对inotify机制有一定的限制


# ll /proc/sys/fs/inotify/
总用量0
-rw-r--r--1 root root 09月923:36 max_queued_events
-rw-r--r--1 root root 09月923:36 max_user_instances
-rw-r--r--1 root root 09月923:36 max_user_watches

# ll /proc/sys/fs/inotify/
总用量0
-rw-r--r--1 root root 09月923:36 max_queued_events
-rw-r--r--1 root root 09月923:36 max_user_instances
-rw-r--r--1 root root 09月923:36 max_user_watches
-----------------------------
max_user_watches #设置inotifywait或inotifywatch命令可以监视的文件数量(单进程)
max_user_instances #设置每个用户可以运行的inotifywait或inotifywatch命令的进程数
max_queued_events #设置inotify实例事件(event)队列可容纳的事件数量

```

------

### 3. 搭建PostgreSQL

*使用harbor-db*

``` yaml
version: '3'
services:
  postgresql:
    image: goharbor/harbor-db:v1.6.0
    container_name: harbor-db
    restart: always
    volumes:
      - /data/database:/var/lib/postgresql/data:z
      - /etc/localtime:/etc/localtime:ro
    network_mode: "host"
    ports:
      - 5432:5432
    env_file:
      - ./db/env
```

```shell
cat ./db/env
POSTGRES_PASSWORD=10jqka@123

vim pg_hba.conf
# IPv4 local connections:
host    all             all             192.168.0.1/16            trust
```

```shell
postgresql.conf
listen_addresses = '0.0.0.0'          # what IP address(es) to listen on;
port = 5432                            # (change requires restart)
max_connections = 100                  # (change requires restart)
wal_log_hints = on
unix_socket_permissions = 0700          # begin with 0 to use octal notation
password_encryption = on
full_page_writes = on
max_locks_per_transaction=400
shared_buffers = 2GB                 # min 128kB
maintenance_work_mem = 2GB           # min 1MB
work_mem=20MB
max_stack_depth = 8MB                   # min 100kB
wal_level = hot_standby                 # minimal, archive, or hot_standby
synchronous_commit = off                # immediate fsync at commit
wal_sync_method = fdatasync             # the default is the first option 
wal_buffers = 128000kB                  # min 32kB
commit_siblings=12
wal_writer_delay = 20ms                 # 1-10000 milliseconds
checkpoint_timeout = 1h              # range 30s-1h
wal_compression = on
max_wal_size = 32GB
archive_mode = off               # allows archiving to be done
archive_command = 'cp %p $PGARCHIVE/%f'         # command to use to archive a logfile segment
max_wal_senders = 15            # max number of walsender processes
wal_keep_segments = 1000        # in logfile segments, 16MB each; 0 disables;
random_page_cost = 2.0                  # same scale as above
effective_cache_size = 12800MB
constraint_exclusion = partition        # on, off, or partition
log_destination = 'csvlog'              # Valid values are combinations of
logging_collector = on          # Enable capturing of stderr and csvlog
log_connections = on            # 
log_directory = 'pg_log'            # directory where log files are written,
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log' # log file name pattern,
log_truncate_on_rotation = on           # If on, an existing log file of the
log_rotation_age = 1d                   # Automatic rotation of logfiles will
log_truncate_on_rotation = on
log_min_duration_statement = 10000ms     # -1 is disabled, 0 logs all statements
log_checkpoints = on
log_lock_waits = on                     # log lock waits >= deadlock_timeout
log_statement = 'ddl'                   # none, ddl, mod, all
log_timezone = 'PRC'
track_activity_query_size = 2048        # (change requires restart)
autovacuum = on               # Enable autovacuum subprocess?  'on' 
log_autovacuum_min_duration = 10 # -1 disables, 0 logs all actions and
check_function_bodies = on
bytea_output = 'escape'                 # hex, escape
datestyle = 'iso, mdy'
lc_messages = 'C'                       # locale for system error message
lc_monetary = 'C'                       # locale for monetary formatting
lc_numeric = 'C'                        # locale for number formatting
lc_time = 'C'                           # locale for time formatting
default_text_search_config = 'pg_catalog.english'
deadlock_timeout = 1s
hot_standby = on                        # 
tcp_keepalives_idle = 60                 # 
max_standby_archive_delay=1000s
max_standby_streaming_delay=1000s
timezone = 'PRC'
zero_damaged_pages=true
restart_after_crash=off
statement_timeout=0
temp_file_limit=15GB
old_snapshot_threshold=1d
```

- [x] 基于容器的方式做主从；

```shell
在主库新建复制用户；
postgres# CREATE ROLE replica login replication encrypted password 'replica';
配置允许用户远程登录；
vim pg_hba.conf
host    replication     replica     192.168.216.101/32                 trust
slave启动后执行；
pg_basebackup -F p --progress -D $PGDATA -h 192.168.216.216 -p 5432 -U replica --password
```



```shell
1、关闭主库，拷贝data目录到备份服务器
pg_ctl stop -m f

2、备库目录下新建文件
recovery.conf，添加以下内容：

standby_mode='on'
recovery_target_timeline = 'latest'
primary_conninfo= 'host=192.168.216.126 port=5432 user=postgres password=10jqka'
trigger_file='/data2/database/trigger_standby'

3、查看主从同步状态
select pid,state,client_addr,sync_priority,sync_state from pg_stat_replication;
```

**使用postgres官方镜像时需初始化数据库，其它步骤与上述一致**

``` shell
# cd /data/harbor/ha
# docker cp initial-registry.sql harbor-db:/tmp
# docker exec -it harbor-db psql -f /tmp/initial-registry.sql
```



------

### 4. 部署harbor双实例

```shell
tar xf harbor-offline-installer-v1.6.0.tgz
cd harbor
vim harbor.cfg
  hostname = hub.hexin.cn:9082
  db_host = 192.168.216.126
  db_password = password
  db_port = 5432
  db_user = postgres
  redis_host = 192.168.216.126
  redis_port = 6379
  redis_password = password
  redis_db_index = 1,2,3
  registry_storage_provider_name = filesystem
  registry_storage_provider_config =
  registry_custom_ca_bundle = 
  

mv docker-compose.yml{,_bak}
cp ha/docker-compose.yml ./
./install.sh --ha

```

``` yaml
version: '2'
services:
  registry:
    image: goharbor/registry-photon:v2.6.2-v1.6.0
    container_name: registry
    restart: always
    volumes:
    # The shared directory
      - /data/shared/registry:/storage:z
      - ./common/config/registry/:/etc/registry/:z
    networks:
      - newharbor
    environment:
      - GODEBUG=netdns=cgo
    command:
      ["serve", "/etc/registry/config.yml"]
    depends_on:
      - log
    logging:
      driver: "syslog"
      options:  
        syslog-address: "tcp://127.0.0.1:1514"
        tag: "registry"
  jobservice:
    image: goharbor/harbor-jobservice:v1.6.0
    container_name: harbor-jobservice
    env_file:
      - ./common/config/jobservice/env
    restart: always
    volumes:
    # job_logs needs in shared directory
      - /data/shared/job_logs:/var/log/jobs:z
      - ./common/config/jobservice/config.yml:/etc/jobservice/config.yml:z
      # must be consistent with harbor.cfg
      - /data2/secretkey:/etc/jobservice/key:z
    networks:
      - newharbor
    depends_on:
      - ui
      - adminserver
    logging:
      driver: "syslog"
      options:
        syslog-address: "tcp://127.0.0.1:1515"
        tag: "jobservice"

```



------

### 5. 搭建keepalived 

- [x] 使用harbor官方提供的配置

``` shell
# ls /data/harbor/ha/sample/*
/data/harbor/ha/sample/active_active:
check.sh  keepalived_active_active.conf

/data/harbor/ha/sample/active_standby:
check_harbor.sh  keepalived_active_standby.conf
```



---

### 数据库迁移方案

官方提供的升级和迁移方案仅适用于，单harbor实例直接升级；计划使用的架构是ha模式，所以原生迁移计划不可用，需改进。经测试，采用以下方案：

```shell
1、在216.113的数据库施加全局读锁：
FLUSH TABLES WITH READ LOCK
2、导出registry的数据：
mysqldump -p --default-character-set=utf8 --databases registry > /tmp/registry.mysql
3、在216.101上起一个harbor1.3.0的实例作为中转，将数据导入此实例数据库，然后升级此实例：
docker pull goharbor/harbor-migrator:v1.6.0
docker-compose down
cp harbor.cfg /root/jeason/backup/harbor/harbor.cfg
docker run -it --rm -e DB_USR=root -e DB_PWD=root123 -v /data/database:/var/lib/mysql -v /root/jeason/backup/harbor/harbor.cfg:/harbor-migration/harbor-cfg/harbor.cfg goharbor/harbor-migrator:v1.6.0 up
4、全量拷贝/data/database下的数据文件到共享数据库，并重启即可；
注意：实例间相关密码要保持一致；拷贝文件时，删掉其中的pid文件。
```

---

## 参考

[harbor ha installation](https://www.cnrancher.com/docs/rancher/v2.x/cn/installation/registry/ha-installation/)

[How to Configure NFS Server Clustering with Pacemaker on CentOS 7 / RHEL 7](https://www.linuxtechi.com/configure-nfs-server-clustering-pacemaker-centos-7-rhel-7/)

[High Availability Add-On Administration](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/high_availability_add-on_administration/ch-startup-haaa)

[在CentOS 7 上使用PaceMaker构建NFS HA服务](https://my.oschina.net/LastRitter/blog/1535871)

[install drbd](http://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html/Clusters_from_Scratch/ch07.html#_install_the_drbd_packages)

[Harbor High Availability Guide](https://github.com/goharbor/harbor/blob/release-1.6.0/docs/high_availability_installation_guide.md)

[Harbor upgrade and database migration guide](https://github.com/goharbor/harbor/blob/release-1.6.0/docs/migration_guide.md)

[Postgresql数据库主从流复制](https://www.centos.bz/2017/09/postgresql%E6%95%B0%E6%8D%AE%E5%BA%93%E4%B8%BB%E4%BB%8E%E6%B5%81%E5%A4%8D%E5%88%B6/)

---

```python
harbor后台加密机制：
采用pbkdf2算法，调用的Hash函数为Sha1，迭代4096次，密钥长度为int型16位得出。
#!/bin/env python 
import hmac
import hashlib
from struct import Struct
from operator import xor
from itertools import izip, starmap


_pack_int = Struct('>I').pack
def pbkdf2_hex(data, salt, iterations=4096, keylen=16, hashfunc=None):
    return pbkdf2_bin(data, salt, iterations, keylen, hashfunc).encode('hex')
def pbkdf2_bin(data, salt, iterations=4096, keylen=16, hashfunc=None):
    hashfunc = hashfunc or hashlib.sha1
    mac = hmac.new(data, None, hashfunc)
    def _pseudorandom(x, mac=mac):
        h = mac.copy()
        h.update(x)
        return map(ord, h.digest())
    buf = []
    for block in xrange(1, -(-keylen // mac.digest_size) + 1):
        rv = u = _pseudorandom(salt + _pack_int(block))
        for i in xrange(iterations - 1):
            u = _pseudorandom(''.join(map(chr, u)))
            rv = starmap(xor, izip(rv, u))
        buf.extend(rv)
    return ''.join(map(chr, buf))[:keylen]
rv = pbkdf2_hex('Liujunfeng@201*', 'bqkaoihidlteezrbeepe03luw5aws3q7', 4096, 16)
print(rv)

```

---

### 异常处理

```shell
错误提示：“harbor failed to initialize the system: read /etc/adminserver/key: is a directory”
原因：harbor.cfg中的secretkey_path和docker-compose.yml中的设置不一致
```

refer：

http://blog.itpub.net/28624388/viewspace-2153546/
