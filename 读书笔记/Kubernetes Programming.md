基于Kubernetes编程：开发一个直接与API Server交互，查询资源状态[并/或]更新其状态的Kubernetes原生应用程序。

Controller实现控制循环，通过API Server监听集群的共享状态，并尝试进行更改以将当前状态转为期望状态。[Kubernetes术语表](https://kubernetes.io/docs/reference/glossary/?fundamental=true)

控制循环（The Control Loop）：
1. 基于事件驱动读取资源状态；
2. 更改集群内或集群外的对象状态；
3. 通过API Server更新步骤1中的资源状态，并存储在etcd中；
4. 重复循环，返回步骤1；


从架构的角度来看，Controller通常使用以下数据结构：

- Informer：以可扩展且可持续的方式监听所需的资源状态，它还实现了强制定期协调的重新同步机制，这种机制通常用于确保集群状态和缓存在内存中的预期状态不会漂移；
- 工作队列（Work Queue）：本质上，工作队列是事件处理程序可以使用的组件，用于状态更新事件的有序处理并协助实现重试。在client-go中，可以通过workqueue package使用此功能。可以在改变环境对象或更新资源状态时发生错误的情况下，进行资源重新分配。或者仅是由于某些原因我们不得不在一段时间后，也需进行资源重新分配。[Kubernetes原理](https://medium.com/@dominik.tornow/the-mechanics-of-kubernetes-ac8112eaa302)

Kubernetes Control Plane大量使用事件和松耦合的组件，Kubernetes Controller监听API Server中Kubernetes对象的操作，如添加、更新和删除等，当发生此类事件时，controller将执行其业务逻辑。

为了进行无锁并发操作，Kubernetes API Server使用乐观并发控制，这意味着如果且当API Server检测到有并发写，它将拒绝两个写操作中的后者，然后由客户端（controller、scheduler、kubectl等）来处理写冲突并重试写操作。
---

从客户端的角度，API Server暴露了一组使用JSON或者protocol buffer（简称protobuf）编码的RESTful HTTP接口。使用protobuf是基于性能上的考虑，主要用于集群内通讯。


API术语

- Kind

实体的类型（The type of an entity），每个对象都有个字段Kind（在JSON里全小写kind，在Golang里首字母大写Kind），它用于告诉客户端（比如kubectl）具体是什么类型，比如说这是一个pod。其中有3种Kind类型：

1. Object代表系统中的持久实体——例如Pod或者Endpoints。Object有名字，并且他们大多数位于namespace中。
2. List代表一个或多个类型实体的集合。List有一组有限的通用元数据（common metadata）。例如，PodList或者NodeList。当你执行kubectl get pods，语义即精确表达你将获取的内容。
3. 特殊用途类型（Special-purpose kinds）主要用于Object和非持久实体的特定操作，例如/binding或者/scale。kubernetes使用APIGroup和APIResource用于资源发现，使用Status类型返回错误结果。

在kubernetes的程序中，Kind直接对应一个Golang的类型（Type）。于是，像Golang类型一样，kubernetes类型（kind）都是用单数形式表示的，且首字母大写。

- API Group

逻辑相关的Kind集合。比如，所有的batch对象如Job或者ScheduledJob，都在batch API Group里。

- Version（版本）

每个API Group可以同时存在多个版本。



desired state

current status