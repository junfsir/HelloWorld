现象描述：

> 1、kubernetes节点，top 查看每颗CPU的si都跑满了；
>
> 2、sar查看包数量大概在1万；iftop查看流量很小；
>
> 3、其他节点上的服务连接此节点上的指定服务，日志报没有可用端口，不能建立连接；
>
> 4、perf top查看connect系统调用占CPU比较高；

分析：

从监控来看，包量及流量不足以因此此现象；且没有可用端口，到具体应用的网络ns查看，发现有接近30000的端口在使用；查看内核参数port_range分配可使用约3万多；

定位：

1. ESTABLISH状态的连接只能有ip_local_port_range范围内的个数；
2. 只有针对特定ip，特定port的TIME-WAIT过多，超过或接近ip_local_port_range，再新建立连接可能会出现无端口可用的情况（ 总的TIME-WAIT过多并不一定有问题 ）；



**问题的根本原因是建立TCP连接使用的端口数量上（ip_local_port_range）不充裕，导致connect系统调用开销上涨了将近100倍！**

后来我们的一位开发同学帮忙翻到了connect系统调用里的一段源码

```
int inet_hash_connect(struct inet_timewait_death_row *death_row,
               struct sock *sk)
{
    return __inet_hash_connect(death_row, sk, inet_sk_port_offset(sk),
            __inet_check_established, __inet_hash_nolisten);
}

int __inet_hash_connect(struct inet_timewait_death_row *death_row,
                struct sock *sk, u32 port_offset,
                int (*check_established)(struct inet_timewait_death_row *,
                        struct sock *, __u16, struct inet_timewait_sock **),
                int (*hash)(struct sock *sk, struct inet_timewait_sock *twp))
{
        struct inet_hashinfo *hinfo = death_row->hashinfo;
        const unsigned short snum = inet_sk(sk)->inet_num;
        struct inet_bind_hashbucket *head;
        struct inet_bind_bucket *tb;
        int ret;
        struct net *net = sock_net(sk);
        int twrefcnt = 1;

        if (!snum) {
                int i, remaining, low, high, port;
                static u32 hint;
                u32 offset = hint + port_offset;
                struct inet_timewait_sock *tw = NULL;

                inet_get_local_port_range(&low, &high);
                remaining = (high - low) + 1;

                local_bh_disable();
                for (i = 1; i <= remaining; i++) {
                        port = low + (i + offset) % remaining;
                        if (inet_is_reserved_local_port(port))
                                continue;
                        ......
        }
}

static inline u32 inet_sk_port_offset(const struct sock *sk)
{
        const struct inet_sock *inet = inet_sk(sk);  
        return secure_ipv4_port_ephemeral(inet->inet_rcv_saddr,  
                                          inet->inet_daddr,  
                                          inet->inet_dport);  
}
```

从上面源代码可见，临时端口选择过程是生成一个随机数，利用随机数在ip_local_port_range范围内取值，如果取到的值在ip_local_reserved_ports范围内 ，那就再依次取下一个值，直到不在ip_local_reserved_ports范围内为止。原来临时端口竟然是随机撞。出。来。的。。也就是说假如就有range里配置了5W个端口可以用，已经使用掉了49999个。那么新建立连接的时候，可能需要调用这个随机函数5W次才能撞到这个没用的端口身上。

所以请记得要保证你可用临时端口的充裕，避免你的connect系统调用进入SB模式。正常端口充足的时候，只需要22usec。但是一旦出现端口紧张，则一次系统调用耗时会上升到2.5ms，整整多出100倍。这个开销比正常tcp连接的建立吃掉的cpu时间（每个30usec左右）的开销要大的多。

> 解决TIME_WAIT的办法除了放宽端口数量限制外，还可以考虑设置net.ipv4.tcp_tw_recycle和net.ipv4.tcp_tw_reuse这两个参数，避免端口长时间保守地等待2MSL时间。



总结：

> 可使用strace -cp $PID来追踪具体服务的系统调用；
>
> 或者perf top；