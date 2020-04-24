# [linux 内核初探 之 内存管理 —— 区 zone]([https://dupengair.github.io/2016/09/17/linux%E5%86%85%E6%A0%B8%E5%AD%A6%E4%B9%A0-%E5%9F%BA%E7%A1%80%E7%AF%87-linux-%E5%86%85%E6%A0%B8%E5%88%9D%E6%8E%A2-%E4%B9%8B-%E5%86%85%E5%AD%98%E7%AE%A1%E7%90%86-%E4%BA%8C-%E2%80%94%E2%80%94-%E5%8C%BA-zone/](https://dupengair.github.io/2016/09/17/linux内核学习-基础篇-linux-内核初探-之-内存管理-二-——-区-zone/))

# 一、基本概念

1. 某些内核页位于特殊的物理地址，用于特殊的应用场合，只能分配特殊范围的内存地址
   - 如老式的ISA设备DMA时只能使用前16M内存
   - 如一些体系结构的内存物理寻址范围远大于虚拟地址，导致一些物理地址不能永久映射到内核空间
2. 内核对具有相似用途的页进行分组，把页划为不同区

# 二、分区

1. ZONE_DMA
   - 定义适合DMA的内存域，该区域的长度依赖于处理器类型。比如ARM所有地址都可以进行DMA，所以该值可以很大，或者干脆不定义DMA类型的内存域。而在IA-32的处理器上，一般定义为16M
2. ZONE_DMA32
   - 只在64位系统上有效，为一些32位外设DMA时分配内存，只能被32位设备访问。如果物理内存大于4G，该值为4G，否则与实际的物理内存大小相同
3. ZONE_NORMAL
   - 定义可直接映射到内核空间的普通内存域。在64位系统上，如果物理内存小于4G，该内存域为空。而在32位系统上，该值最大为896M
4. ZONE_HIGHMEM
   - 只在32位系统上有效，标记超过896M范围的内存。在64位系统上，由于地址空间巨大，超过4G的内存都分布在ZONE_NORMAL内存域
5. ZONE_MOVABLE
   - 伪内存域，为了实现减小内存碎片的机制

# 三、说明

1. 分区没有任何物理意义，只是内核为管理物理页而在逻辑上的分组
2. 内核把页划分为区，形成不同的内存池，就能根据用途进行分配了
3. 除了其余几个区各取所需，剩下的空间就由NOrRMAL独享
4. 某些分配可能要从特定的区中获取页，如DMA，一般用途可以从多个区中获取，如既可以是DMA也可以是NORMAL，注意分配不能跨区
5. 一般按用途分配，本区域不够用时才会从其它区域分配

# 四、struct zone <linux/mmzone.h>

```c
struct zone {
    /* zone watermarks, access with *_wmark_pages(zone) macros */
    unsigned long watermark[NR_WMARK]; /* 内存回收的水线 */
    /* 为什么是per-cpu? ,因为每个cpu都可从当前zone中分配内存，而pageset本身实现的一个功能就是批量申请和释放修改为per-cpu可减小多个cpu在申请内存时的所竞争*/
    struct per_cpu_pageset __percpu *pageset;
    /*
     * free areas of different sizes
     */
    spinlock_t        lock;
    struct free_area    free_area[MAX_ORDER]; /* 空闲内存链表，按幂次分组，用于实现伙伴系统 */
    /* Zone statistics */
    atomic_long_t        vm_stat[NR_VM_ZONE_STAT_ITEMS]; /* 内存状态统计 */

    /*
     * The target ratio of ACTIVE_ANON to INACTIVE_ANON pages on
     * this zone's LRU. Maintained by the pageout code.
     */
    unsigned int inactive_ratio;
    ...
};
```

1. wartermark
   - 定义内存回收的水线，有三种水线：WMARK_HIGH、WMARK_LOW、WMARK_MIN。内核线程kswapd检测到不同的水线值会进行不同的处理，当空闲page数大于high时，内存域状态理想，不需要进行内存回收；当空闲page数低于low时，开始进行内存回收，将page换出到硬盘；当空闲page数低于min时，表示内存回收的压力很重，因为内存域中的可用page数已经很少了，必须加快进行内存回收
2. pageset
   - per-cpu变量，用于实现每cpu内存的批量申请和释放，减小申请内存时的锁竞争，加快分配内存的速度
3. free_area
   - 空闲内存链表，按order进行分组，构建伙伴系统模型。同时，为了减少内存碎片，每种order下又根据迁移类型进行了分类。`free_area`数组是停用bootmem分配器、释放bootmem内存时建立起来的
4. vmstat
   - 用于维护zone中的大量统计信息，在同步和内存回收时非常有用
5. lock
   - 自旋锁，只保护结构本身，不保护驻留在内存中的所有页，也没有特定的锁来保护单个 页

# 五、内存“价值”层次结构

1. 内核为内存域定义了一个“价值”的层次结构，按分配的“廉价度”依次为：`ZONE_HIGHMEM > ZONE_NORMAL > ZONE_DMA`
2. 高端内存域是最廉价的，因为内核没有任何部分依赖于从该zone中分配内存，如果高端内存用尽，对内核没有任何副作用，这也是优先分配高端内存的原因
3. 普通内存域有所不同，因为所有的内核数据都保存在该区域，如果用尽内核将面临紧急情况，甚至崩溃
4. DMA内存域是最昂贵的，因为它不但数量少很容易被用尽，而且被用于与外设进行DMA交互，一旦用尽则失去了与外设交互的能力
5. 因此内核在进行内存分配时，优先从高端内存进行分配，其次是普通内存，最后才是DMA内存