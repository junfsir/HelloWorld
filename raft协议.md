[raft协议图解](http://thesecretlivesofdata.com/raft/)

一致性（Consistency）是指集群中的多个节点在状态上达成一致，可以保证在集群中大部分节点可用（超过半数以上的节点可用）的情况下，集群依然可以工作并返回正确结果，从而保证依赖于该集群的其他服务不受影响；

`raft`算法是一种用于管理复制日志的一致性算法，保证可被提交的日志条目是持久化的，并且最终会被所有的状态机执行的；

**节点的3种状态：**

- `Leader`节点负责处理所有客户端的请求，并将客户端的更新操作以`Append Entry`的形式发送到集群中所有`Follower`节点；当接收到客户端的写入请求时，`Leader`节点会在本地追加一条响应的`Entry`，然后将其封装成`Message`发送到集群中其他的`Follwer`节点；当`Follower`节点收到该`Message`时会对其进行响应；如果集群中多数（超过半数）节点都已收到该请求对应的`Entry`时，则`Leader`节点认为该条`Entry`已`Commited`，可以向客户端返回响应；`Leader`还会处理客户端的只读请求；`Leader`节点的另一项工作是定期向集群中的`Follower`节点发送心跳消息，主要是为了防止集群中的其他`Follower`节点的选举计时器超时而触发新一轮选举；
- `Follower`节点不会发送任何请求，它们只是简单地响应来自`Leader`或者`Candidate`的请求；`Follower`节点也不处理`Client`请求，而是将请求重定向给集群`Leader`节点进行处理；
- `Candidate`节点是由`Follower`节点转换而来的，当`Follower`节点长时间没有收到`Leader`发送的心跳信息时，则该节点的选举计时器就会过期，同时会将自身状态转换为`Candidate`，发起新一轮选举；每个`Candidate`的第一张选票来自自己；

**2个超时时间：**

- 选举超时时间（`election timeout`）：每个Follower节点在接收不到`Leader`节点的心跳消息之后，并不会立即发起新一轮选举，而是要等待一段时间之后才切换为`Candidate`状态发起新一轮选举，其值为`150ms-300ms`之间的随机数；
- 心跳超时时间（`heartbeat timeout`）：`Leader`节点向集群中其他`Follower`节点发送心跳消息的时间间隔；
- 广播时间 << 选举超时时间 << 平均故障间隔时间；
- 心跳超时时间 << 选举超时时间；

**任期（Term）：**

全局、连续递增的整数，每进行一次选举，`Term`加一，在每个节点中都会记录当前的`Term`；每一个任期都是从一次选举开始的，在选举时，会出现一个或多个`Candidate`节点尝试成为`Leader`节点，如果其中一个`Candidate`节点赢得选举，则该节点就会切换为`Leader`并成为该任期的`Leader`节点，直到任期结束；

知识点：

- 复制状态机：保证所有的状态机都以相同的顺序执行这些指令；
- 顺序一致性：也成为可序列化，指所有的进程都已相同的顺序看到所有的修改；

**复制状态机之所以能够正常工作是基于这样的假设**

如果一些状态机具有相同的初始状态，并且它们接收到的命令也相同，处理这些命令的顺序也相同，那么它们处理完这些命令后的状态也应该相同；

**写日志**

在`Raft`算法中，`Leader`通过强制`Follower`复制它的日志来处理日志不一致问题；这就意味着，`Follower`上与`Leader`的冲突日志都会被`Leader`的日志强制覆写；

1. 客户端向`Leader`发送写请求；
2. `Leader`将写请求解析为操作指令追加到本地日志文件（`WAL`）中；
3. `Leader`为每个`Follower`广播`AppendEntries RPC`；
4. `Follower`通过一致性检查，选择从哪个位置开始追加`Leader`的日志条目；
5. 一旦日志提交成功，`Leade`r将该日志条目对应的指令`apply`到本地状态机，并向客户端返回操作结果；
6. `Leader`后续通过`AppendEntries RPC`将已经成功的日志项告知`Follower`；
7. `Follower`收到提交的日志项后，将其应用到本地状态机；

**Leader如何定位与各Follower之间的不一致日志条目**

`Leader`为每个`Follower`维护一个`nextIndex`，它表示`Leader`将要发送给`Follower`的下一条日志条目的索引；当一个`Leader`赢得选举时，会假设每个`Follower`的日志与自己的保持一致，于是先将`nextIndex`初始化为它最新的`日志条目索引+1`；当`Leader`向`Follower`发送`AppendEntries RPC`时，它携带了（`term_id，nextIndex-1`）二元组信息；`Follower`收到`AppendEntries RPC`消息后，会进行一致性检查，即检索自己的日志文件中是否存在这样的日志条目，如果不存在，就向`Leader`返回`AppendEntries RPC`失败；如果返回失败信息，就意味着`Follower`发现自己的日志与`Leader`的不一致；在失败之后，`Leader`会将`nextIndex`递减，然后重试`AppendEntries RPC`，直到`AppendEntries RPC`返回成功；

**Q&A**

1. 怎样才能具有称为`Leader`的资格；

`Leader`必须最终必须要存储全部已经提交的日志条目；`Raft`算法使用投票的方式来阻止那些没有包含所有已提交日志条目的节点赢得选举；`RequestVote RPC`的接收方有一个检查：如果它自己的日志比`RPC`调用方的日志更新，就会拒绝候选人的投票；比较日志更新的依据：如果两个日志条目的任期号不同，则任期号大的更新，如果任期号相同，则索引更大的日志更新；

**异常情况**

1. `Follower`或者`Candidate`异常；

如果`Follower`或者`Candidate`异常后，Leader在此之后发送的`AppendEntries RPC`就会失败，Raft算法通过Leader无限地重试来应对这些失败，直到故障的节点重启并处理了这些RPC为止；如果一个节点在收到RPC之后但在响应之前就崩溃了，那么它会在重启之后再次收到同一个RPC；Raft算法中的RPC是幂等的；

当Client向集群Leader提交数据时，Leader节点接收到的数据处于未提交状态（Uncommitted），接着Leader节点会并发向所有Follower节点复制数据并等待接收响应，在确保集群中至少超过半数的节点已经接收到数据之后，再向Client确认数据已接收；一旦Leader节点向Client发出数据接收ACK相应之后，即表明此时数据状态进入已提交（Committed）状态，Leader节点会再次向Follower节点发出通知，告知该数据状态已提交；

2. 数据到达Leader前Leader故障；

不会影响数据一致性；

3. 数据到达Leader节点，但未复制到Follower节点；

如果在这个阶段Leader出现故障，此时数据处于未提交状态，那么Client不会收到ACK，而是会认为超时失败可安全发起重试；Follower节点上没有该数据，重新选主后Client重新重试提交可成功；原来的Leader节点恢复之后将作为Follower加入集群，重新从当前任期的新Leader处同步数据，与Leader数据强制保持一致；

4. 数据到达Leader节点，成功复制到Follower的部分节点上，但还未向Leader相应接收；

如果在这个阶段Leader节点出现故障，此时数据在Follower节点处于未提交状态且不一致，那么Raft协议要求投票只能投给拥有最新数据的节点；所以拥有最新数据的节点会被选为Leader，再将数据强制同步到Follower，数据不会丢失并且能够保证最终一致；

5. 数据到达Leader节点，成功复制到Follower的所有节点上，但未向Leader相应接收；

如果在这个阶段Leader出现故障，虽然此时数据在Follower节点处于未提交状态，但也能保持一致，那么重新选出Leader后即可完成数据提交，由于此时Client不知到底有没有提交成功，因此可重试提交；针对这种情况，Raft要求RPC请求实现幂等性，也就是要实现内部去重机制；

6. 数据到达Leader节点，成功复制到Follower的所有或者大多数节点上，数据在所有节点处于已提交状态，但还未相应Client

此时集群内部数据已经一致，那么Client重复重试基于幂等性策略对一致性无影响；



[Raft algorithm: What's the meaning of concept index?](https://cs.stackexchange.com/questions/97542/raft-algorithm-whats-the-meaning-of-concept-index)

```shell
a log index in Raft algorithm is just an integer that tells the position of a log entry in a series of log entries.
```