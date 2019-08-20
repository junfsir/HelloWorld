### 独立网卡做bond(先在服务器操作后再设置交换机)

```shell
 ~]# cat /etc/sysconfig/network-scripts/ifcfg-bond0 
DEVICE=bond0
NAME=bond0
TYPE=Bond
ONBOOT=yes
BOOTPROTO=none
BONDING_MASTER=yes
USERCTL=no
BONDING_OPTS="miimon=100 mode=0"
NM_CONTROLLED=no
BRIDGE=br0
 ~]# cat /etc/sysconfig/network-scripts/ifcfg-br0 
TYPE=Bridge
BOOTPROTO=none
NAME=br0
DEVICE=br0
ONBOOT=yes
IPADDR=10.200.0.195
USERCTL=no
NM_CONTROLLED=no
NETMASK=255.254.0.0
GATEWAY=10.200.0.1 
DEFROUTE=yes  
 ~]# cat /etc/sysconfig/network-scripts/ifcfg-ens6f0 
TYPE=Ethernet
DEVICE=ens6f0
NAME=ens6f0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
 ~]# cat /etc/sysconfig/network-scripts/ifcfg-ens6f1 
TYPE=Ethernet
DEVICE=ens6f1
NAME=ens6f1
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
MASTER=bond0
SLAVE=yes
 ~]# cat /etc/modprobe.conf 
alias bond0 bonding
options bond0 miimon=100 mode=0
 ~]# lsmod |grep bonding || modprobe bonding
bonding               139264  0 
 ~]# systemctl restart network.service
 ~]# ethtool bond0
Settings for bond0:
	Supported ports: [ ]
	Supported link modes:   Not reported
	Supported pause frame use: No
	Supports auto-negotiation: No
	Advertised link modes:  Not reported
	Advertised pause frame use: No
	Advertised auto-negotiation: No
	Speed: 2000Mb/s
	Duplex: Full
	Port: Other
	PHYAD: 0
	Transceiver: internal
	Auto-negotiation: off
	Link detected: yes
```

### 设置中断亲和性

```shell
# setting up irq affinity according to /proc/interrupts
# 2008-11-25 Robert Olsson
# 2009-02-19 updated by Jesse Brandeburg
#
# > Dave Miller:
# (To get consistent naming in /proc/interrups)
# I would suggest that people use something like:
#       char buf[IFNAMSIZ+6];
#
#       sprintf(buf, "%s-%s-%d",
#               netdev->name,
#               (RX_INTERRUPT ? "rx" : "tx"),
#               queue->index);
#
#  Assuming a device with two RX and TX queues.
#  This script will assign: 
#
#       eth0-rx-0  CPU0
#       eth0-rx-1  CPU1
#       eth0-tx-0  CPU0
#       eth0-tx-1  CPU1
#

set_affinity()
{
    MASK=$((1<<$VEC))
    printf "%s mask=%X for /proc/irq/%d/smp_affinity\n" $DEV $MASK $IRQ
    printf "%X" $MASK > /proc/irq/$IRQ/smp_affinity
    #echo $DEV mask=$MASK for /proc/irq/$IRQ/smp_affinity
    #echo $MASK > /proc/irq/$IRQ/smp_affinity
}

if [ "$1" = "" ] ; then
        echo "Description:"
        echo "    This script attempts to bind each queue of a multi-queue NIC"
        echo "    to the same numbered core, ie tx0|rx0 --> cpu0, tx1|rx1 --> cpu1"
        echo "usage:"
        echo "    $0 eth0 [eth1 eth2 eth3]"
fi


# check for irqbalance running
IRQBALANCE_ON=`ps ax | grep -v grep | grep -q irqbalance; echo $?`
if [ "$IRQBALANCE_ON" == "0" ] ; then
        echo " WARNING: irqbalance is running and will"
        echo "          likely override this script's affinitization."
        echo "          Please stop the irqbalance service and/or execute"
        echo "          'killall irqbalance'"
fi

#
# Set up the desired devices.
#

for DEV in $*
do
  for DIR in rx tx TxRx
  do
     MAX=`grep $DEV-$DIR /proc/interrupts | wc -l`
     if [ "$MAX" == "0" ] ; then
       MAX=`egrep -i "$DEV:.*$DIR" /proc/interrupts | wc -l`
     fi
     if [ "$MAX" == "0" ] ; then
       echo no $DIR vectors found on $DEV
       continue
       #exit 1
     fi
     for VEC in `seq 0 1 $MAX`
     do
        IRQ=`cat /proc/interrupts | grep -i $DEV-$DIR-$VEC"$"  | cut  -d:  -f1 | sed "s/ //g"`
        if [ -n  "$IRQ" ]; then
          set_affinity
        else
           IRQ=`cat /proc/interrupts | egrep -i $DEV:v$VEC-$DIR"$"  | cut  -d:  -f1 | sed "s/ //g"`
           if [ -n  "$IRQ" ]; then
             set_affinity
           fi
        fi
     done
  done
done
```

设置队列长度

```shell
ethtool  -G enp4s0f0 tx 4096
ethtool  -G enp4s0f0 rx 4096
ethtool  -G enp4s0f1 tx 4096
ethtool  -G enp4s0f1 rx 4096
```

### Issue

运行脚本设置中断后，`cat /proc/interrupts`当时观察中断情况确实绑定到了对应的CPU，但是一段时间后观察，绑定已失效，后查明原因是`irqbalance`这个进程重新进行了调度，所以需停掉该进程后，重新绑定；

```shell
 ~]# systemctl disable irqbalance
 ~]# systemctl stop irqbalance
 ~]# sh /root/bindirq.sh ens6f0 ens6f1
```

**参考**

[网卡多队列及中断绑定](https://blog.csdn.net/wyaibyn/article/details/14109325)
[设备中断绑定到特定CPU(SMP IRQ AFFINITY)](http://smilejay.com/2012/02/irq_affinity/)
[cpuspeed和irqbalance服务器的两大性能杀手](http://wubx.net/stop-irqbalance-and-cpuspeed/)

---

单CPU处理网络IO存在瓶颈, 目前经常使用网卡多队列提高性能.



通常情况下, 每张网卡有一个队列(queue), 所有收到的包从这个队列入, 内核从这个队列里取数据处理. 该队列其实是ring buffer(环形队列), 内核如果取数据不及时, 则会存在丢包的情况.
一个CPU处理一个队列的数据, 这个叫中断. 默认是cpu0(第一个CPU)处理. 一旦流量特别大, 这个CPU负载很高, 性能存在瓶颈. 所以网卡开发了多队列功能, 即一个网卡有多个队列, 收到的包根据TCP四元组信息hash后放入其中一个队列, 后面该链接的所有包都放入该队列. 每个队列对应不同的中断, 使用irqbalance将不同的中断绑定到不同的核. 充分利用了多核并行处理特性. 提高了效率.

### 多网卡队列实现图例

```
             普通单队列                                   
   +-----------------------------+                        
   | queue                       |                        
   |                             |                        
   |   +----------+  +----------+|           +---------+  
   |   |  packet  |  |  packet  ||---------->|  CPU 0  |  
   |   +----------+  +----------+|           +---------+  
   +-----------------------------+                        
                                                    
                             开启多网卡队列               
                                                        
    +----------------------------+                       
    | queue                      |                       
    |                            |                       
    |  +----------+ +----------+ |           +---------+ 
    |  |  packet  | |  packet  | |---------> |  CPU 0  | 
    |  +----------+ +----------+ |           +---------+ 
    +----------------------------+           +---------+ 
                                             |  CPU 1  |  
                                             +---------+  
                                             +---------+  
    +----------------------------+           |  CPU 2  |  
    | queue                      |           +---------+  
    |                            |                        
    |  +----------+ +----------+ |           +---------+  
    |  |  packet  | |  packet  | |---------> |  CPU 3  |  
    |  +----------+ +----------+ |           +---------+  
    +----------------------------+                        
```

### 检查中断与对应的CPU关系

如下显示, 第一列是中断号, 后面两列是对应CPU处理该中断的次数, virtio-input和 virtio-output为网卡队列的中断 可见大部分包被CPU1处理

```bash
# cat /proc/interrupts | egrep 'CPU|virtio.*(input|output)'
           CPU0       CPU1
 27:          7      89632   PCI-MSI-edge      virtio3-input.0
 30:          2          0   PCI-MSI-edge      virtio3-output.0
 31:          7      23319   PCI-MSI-edge      virtio3-input.1
 32:          2          0   PCI-MSI-edge      virtio3-output.1
```

查询具体中断所绑定的CPU信息
smp_affinity_list显示CPU序号. 比如 0 代表 CPU0, 2代表 CPU2 smp_affinity 是十六进制显示. 比如 2 为10, 代表 CPU1 (第二个CPU)

```bash
# for i in {30..32}; do echo -n "Interrupt $i is allowed on CPUs "; cat /proc/irq/$i/smp_affinity_list; done
Interrupt 30 is allowed on CPUs 0
Interrupt 31 is allowed on CPUs 1
Interrupt 32 is allowed on CPUs 0
```

### RPS, XPS, RFS

之前谈的多网卡队列需要硬件实现, RPS则是软件实现,将包让指定的CPU去处理中断.
配置文件为`/sys/class/net/eth*/queues/rx*/rps_cpus`. 默认为0, 表示不启动RPS 如果要让该队列被CPU0,1处理, 则设置 echo “3” > /sys/class/net/eth*/queues/rx*/rps_cpus, 3代表十六进制表示11, 即指CPU0和CPU1
在开启多网卡队列RSS时, 已经起到了均衡的作用. RPS则可以在队列数小于CPU数时, 进一步提升性能. 因为进一步利用所有CPU. RFS则进一步扩展RPS的能力, 它会分析并将包发往最合适的CPU(程序运行所在的CPU). 检查当前RPS, RFS开启情况:

```bash
# for i in $(ls -1 /sys/class/net/eth*/queues/rx*/rps_*); do echo -n "${i}:  "  ; cat ${i}; done
/sys/class/net/eth0/queues/rx-0/rps_cpus:  3
/sys/class/net/eth0/queues/rx-0/rps_flow_cnt:  4096
/sys/class/net/eth0/queues/rx-1/rps_cpus:  3
/sys/class/net/eth0/queues/rx-1/rps_flow_cnt:  4096
# cat /proc/sys/net/core/rps_sock_flow_entries
8192
```

XPS是将发送包指定到CPU, 通常和同一队列的rps和xps配置一致.

```bash
# for i in $(ls -1 /sys/class/net/eth*/queues/tx*/xps_cpus); do echo -n "${i}:  "  ; cat ${i}; done
/sys/class/net/eth0/queues/tx-0/xps_cpus:  3
/sys/class/net/eth0/queues/tx-1/xps_cpus:  3
```

### 根据top输出查看软中断负载

top进入交互式界面后, 按1 显示所有cpu的负载. si 是软中断的CPU使用率. 如果高比如50%, 说明该CPU忙于处理中断, 通常就是收发网络IO

```
top - 18:58:33 up 16 days, 19:58,  2 users,  load average: 0.00, 0.01, 0.05
Tasks:  89 total,   2 running,  87 sleeping,   0 stopped,   0 zombie
%Cpu0  :  1.3 us,  0.0 sy,  0.0 ni, 98.7 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  3880032 total,  2911912 free,   199600 used,   768520 buff/cache
KiB Swap:        0 total,        0 free,        0 used.  3411892 avail Mem
```

### 参考

<https://www.kernel.org/doc/Documentation/IRQ-affinity.txt>
<https://www.kernel.org/doc/Documentation/networking/scaling.txt>
<https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/performance_tuning_guide/sect-red_hat_enterprise_linux-performance_tuning_guide-networking-configuration_tools#sect-Red_Hat_Enterprise_Linux-Performance_Tuning_Guide-Configuration_tools-Configuring_Receive_Packet_Steering_RPS>
<https://lwn.net/Articles/370153/>
<https://lwn.net/Articles/412062/>

---

##### 什么是中断?

由于接收来自外围硬件(相对于CPU和内存)的异步信号或者来自软件的同步信号，而进行相应的硬件、软件处理；发出这样的信号称为进行中断请求(interrupt request, IRQ)

##### 硬中断与软中断?

- **硬中断**：外围硬件发给CPU或者内存的异步信号就称之为硬中断
- **软中断**：由软件系统本身发给操作系统内核的中断信号，称之为软中断。通常是由硬中断处理程序或进程调度程序对操作系统内核的中断，也就是我们常说的系统调用(System Call)

##### 硬中断与软中断之区别与联系？

1. 硬中断是有外设硬件发出的，需要有中断控制器之参与。其过程是外设侦测到变化，告知中断控制器，中断控制器通过CPU或内存的中断脚通知CPU，然后硬件进行程序计数器及堆栈寄存器之现场保存工作（引发上下文切换），并根据中断向量调用硬中断处理程序进行中断处理
2. 软中断则通常是由硬中断处理程序或者进程调度程序等软件程序发出的中断信号，无需中断控制器之参与，直接以一个CPU指令之形式指示CPU进行程序计数器及堆栈寄存器之现场保存工作(亦会引发上下文切换)，并调用相应的软中断处理程序进行中断处理(即我们通常所言之系统调用)
3. 硬中断直接以硬件的方式引发，处理速度快。软中断以软件指令之方式适合于对响应速度要求不是特别严格的场景
4. 硬中断通过设置CPU的屏蔽位可进行屏蔽，软中断则由于是指令之方式给出，不能屏蔽
5. 硬中断发生后，通常会在硬中断处理程序中调用一个软中断来进行后续工作的处理
6. 硬中断和软中断均会引起上下文切换(进程/线程之切换)，进程切换的过程是差不多的