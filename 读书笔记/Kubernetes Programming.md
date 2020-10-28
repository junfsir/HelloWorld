### 第一章 导论

#### 基于Kubernetes编程的定义：

> 开发一个直接与API Server交互，查询资源状态[并/或]更新其状态的Kubernetes原生应用程序。

#### 扩展模式：

- 传统的云服务提供商都是作为controller manager的一部分存在于主代码仓库（in-tree）中的。从1.11版本开始，kubernetes通过提供与云集成的自定义cloud-controller-manager process，使独立于主代码仓库（out-of-tree）进行开发成为可能。云服务提供商允许使用特定于云服务提供商的工具，例如负载均衡器或虚拟机。
- 用于[网络](https://github.com/containernetworking/cni)、[设备](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/)（例如GPU），[存储](https://github.com/container-storage-interface/spec/blob/master/spec.md)和[容器运行时](https://github.com/kubernetes/community/blob/master/contributors/devel/sig-node/container-runtime-interface.md)的二进制Kubelet插件。
- 二进制kubectl[插件](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/)。
- API Server中的访问扩展，例如webhooks的动态准入控制。
- 自定义资源和自定义controller；
- 自定义API Server；
- 调度器扩展，例如使用[webhook](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/scheduling/scheduler_extender.md)来实现自己的调度决策。
- 通过webhook进行[身份验证](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#webhook-token-authentication)。

#### Controller和Operator

Controller实现控制循环，通过API Server监听集群的共享状态，并尝试进行更改以将当前状态转为期望状态。[Kubernetes术语表](https://kubernetes.io/docs/reference/glossary/?fundamental=true)

##### 控制循环（The Control Loop）：

1. 基于事件驱动读取资源状态；
2. 更改集群内或集群外的对象状态；
3. 通过API Server更新步骤1中的资源状态，并存储在etcd中；
4. 重复循环，返回步骤1；

![Kubernetes的控制循环](../images/Kubernetes Programming/Kubernetes的控制循环.png)


从架构的角度来看，Controller通常使用以下数据结构：

- Informer：以可扩展且可持续的方式监听所需的资源状态，它还实现了强制定期协调的重新同步机制，这种机制通常用于确保集群状态和缓存在内存中的预期状态不会漂移；
- 工作队列（Work Queue）：本质上，工作队列是事件处理程序可以使用的组件，用于状态更新事件的有序处理并协助实现重试。在client-go中，可以通过workqueue package使用此功能。可以在改变环境对象或更新资源状态时发生错误的情况下，进行资源重新分配。或者仅是由于某些原因我们不得不在一段时间后，也需进行资源重新分配。[Kubernetes原理](https://medium.com/@dominik.tornow/the-mechanics-of-kubernetes-ac8112eaa302)

##### 事件

Kubernetes Control Plane大量使用事件和松耦合的组件，Kubernetes Controller监听API Server中Kubernetes对象的操作，如添加、更新和删除等，当发生此类事件时，controller将执行其业务逻辑。

以下为通过deployment来启动pod，所涉及的controller和其他control plane组件的协同工作：

1. Deployment controller（在kube-controller-manager内部）感知到（通过deployment informer）用户创建了一个deployment。根据其业务逻辑，它将创建一个replica set。
2. Replica set controller（同样在kube-controller-manager内部）感知到（通过replica set informer）新的replica set被创建了。并随后运行其业务逻辑，它将创建一个pod对象。
3. Scheduler（在kube-scheduler二进制文件内部）——同样是一个controller，感知到（通过pod informer）pod设置了一个空的spec.Nodename字段。根据其业务逻辑，它将该pod放入其调度队列中。
4. 与此同时，另一个controller Kubelet（通过其pod informer）感知到有新的pod出现，但是新的pod的spec.Nodename字段为空，因此与Kubelet的node name不匹配。它会忽略该pod并返回休眠状态（直到下一个事件）。
5. Scheduler更新pod的spec.Nodename字段，并将该字段写入API Server，由此将此pod从工作队列中移出，并调度至具有足够可用资源的node上。
6. 由于pod的更新事件，Kubelet将再次唤醒，这次再将pod 的spec.Nodename与自己的node name进行比较，会发现是匹配的，接着Kubelet将启动pod中的容器，并将容器已启动的信息写入pod status中，由此上报给API Server。
7. Replica set controller会感知到已更新的pod，但并不会做什么。
8. 如果pod停止，Kubelet将感知到该事件，进而从API Server获取pod对象，并把pod status设置为”terminated“，然后将其回写至API server。
9. Replica set controller会感知到终止的pod，并决定更换此pod。他将在API server上删除终止了的pod，然后创建一个新的pod。
10. 以此类推。

###### 监听事件和Event对象

- 监听事件是通过API server和controller之间的http长连接发送，从而驱动informer。
- 顶级的Event对象是诸如pod、deployment或service资源具有的特殊属性，它的存在时间为一个小时，然后自动从etcd删除。Event对象只是用户可见的日志记录机制。许多controller创建这些事件，以便其将业务逻辑的各个方面传达给用户。

> 事件即状态变化。

##### 边缘驱动触发和水平驱动触发

原则上有两种方法可检测状态变化（事件本身）：

- 边缘驱动触发（Edge-driven triggers）

在状态变化发生的时间点，将触发处理程序。例如，从无pod运行到pod运行。

- 水平驱动触发（Level-driven triggers）

定期检查状态，如果满足某些条件（例如，pod正在运行），则会触发处理程序。

后者是轮询的一种形式。它不能随对象数量的扩展而高效的扩展，而且controller感知到变化的延迟取决于轮询的间隔以及API server的响应速度。由于涉及到许多异步controller，导致系统需要较长的时间才能满足用户的需求。

对于许多对象，前一种方法效率更高。延迟主要取决于controller处理事件的工作线程数。因此，kubernetes是基于事件的模式（即边缘驱动触发）。

在 kubernetes controller plane中，许多组件会更改API server上的对象，每个更改都会导致事件的产生。我们称这些组件为事件源（event source）或事件产生者。另一方面，在controller上下文中，我们对事件的消费感兴趣，即何时对事件作出何种响应（通过informer）。

##### 更改集群内或集群外对象

基于controller更改资源状态不一定意味着资源本身必须是kubernetes集群的一部分。换句话说，controller可以更改位于kubernetes外部的资源（例如云存储服务）的状态。例如，AWS Service Operator允许您管理AWS资源。除此之外，它还许您管理S3 bucket——也就是说，S3 controller监控kubernetes外部存在的资源（S3 bucket），并且把生命周期中的各种状态变化反馈出来：比如创建和删除S3 bucket。

#### 乐观并发

为了进行无锁并发操作，Kubernetes API Server使用乐观并发控制，这意味着如果且当API Server检测到有并发写，它将拒绝两个写操作中的后者，然后由客户端（controller、scheduler、kubectl等）来处理写冲突并重试写操作。

> 资源版本号实际上是etcd键值对的版本号。每个对象的资源版本是kubernetes中的一个字符串，其中包含一个整数。这个整数直接来自etcd。etcd维护着一个计数器，每次修改键的值时，计数器都会增加。
>
> 在整个API机制代码中，资源版本号像任意字符串一样处理，但是带有一些顺序。存储成整数的实现方式只是当前etcd存储后端的实现细节。

### 第二章 kubernetes API基础

#### API server

**核心职责：**

- 提供kubernetes API。这些API供集群内的主控组件、工作节点、kubernetes原生应用，以及外部客户端调用；
- 代理集群组件，比如kubernetes仪表盘，流式日志，服务端口，kubectl exec 会话。

**API  server的http接口**

从客户端的角度，API Server暴露了一组使用JSON或者protocol buffer（简称protobuf）编码的RESTful HTTP接口。使用protobuf是基于性能上的考虑，主要用于集群内通讯。

#### API术语

- Kind

实体的类型（The type of an entity），每个对象都有个字段Kind（在JSON里全小写kind，在Golang里首字母大写Kind），它用于告诉客户端（比如kubectl）具体是什么类型，比如说这是一个pod。其中有3种Kind类型：

1. Object代表系统中的持久实体——例如Pod或者Endpoints。Object有名字，并且他们大多数位于namespace中。
2. List代表一个或多个类型实体的集合。List有一组有限的通用元数据（common metadata）。例如，PodList或者NodeList。当你执行kubectl get pods，语义即精确表达你将获取的内容。
3. 特殊用途类型（Special-purpose kinds）主要用于Object和非持久实体的特定操作，例如/binding或者/scale。kubernetes使用APIGroup和APIResource用于资源发现，使用Status类型返回错误结果。

在kubernetes的程序中，Kind直接对应一个Golang的类型（Type）。于是，像Golang类型一样，kubernetes类型（kind）都是用单数形式表示的，且首字母大写。

- API Group

逻辑相关的Kind集合。比如，所有的batch对象如Job或者ScheduledJob，都在batch API Group里。

- Version（版本）

每个API Group可以同时存在多个版本。不存在这样 的说法：”在集群内一个对象是v1，而另一个对象是v1beta1“。而应当是，每一个对象可以用v1的版本返回，也可以用v1beta1的版本返回，根据用户不同的期望来决定返回的版本。

- Resource（资源）

通常是小写复数形式的单词（比如pods），用以表示一组HTTP endpoints（路径），以此暴露系统中某个对象类型的CRUD（创建、读取、更新、删除）语义的接口。

常见路径是：

- [x] 根路径，可以列出该类型下所有的实例，如：.../pods。
- [x] 单个命名资源的路径，如：.../pods/nginx。

通常，每种endpoints的返回和接收一种kind。其他情况下（比如，报错的情况下），会返回一个Status kind的对象。主资源除了具备完整的CRUD语义之外，还可以有更进一步的endpoint以完成特定的行为（比如 .../pod/nginx/port-forward，.../pod/nginx/exec，或者.../pod/nginx/logs）。我们称之为subresource。这些subresource通常实现了自定义协议替代REST——比如，有些通过websocket实现的流式链接或者命令式API。

> Resource和kind的明显区别：
>
> - Resource会有对应的http路径；
> - Kind是被这些endpoints（http路径）所返回或者接收的对象的类型，会持久化存储在etcd中。

Resource永远是API Group和Version的一部分。统称为GroupVersionResource（GVR）。一个GVR唯一定义一个http路径。一个固定的路径，例如，在default的namespace中，它会是/apis/batch/v1/namespces/default/jobs。

![GVR](../images/Kubernetes Programming/GVR.png)

与jobs的GVR不同的是，集群层面的资源，比如node和namespace本身，它们的路径是没有$NAMESPACE的。例如，nodes的GVR看起来是这样的：/api/v1/nodes。注意，namespace会显示在其他资源http路径中，但namespace本身也是一种资源，可通过/api/v1/namespaces访问。

与GVR类似，每种kind也存在于API Group之下，且有版本标记，且通过GroupVersionKind（GVK）标识。

> 共栖——存在于多个API Group下的Kind
>
> 同名的Kind不仅可以存在不同的versions下，也可以同时存在不同的API Group下。比如Deployment一开始是在扩展组里的alpha kind，后来提升为稳定版本之后，进入它自己的组——apps.k8s.io。我们称这种现象为cohabitation（共栖）。这种情况在kubernetes里并不常见，屈指可数：
>
> - Ingress，NetworkPolicy分别在extensions和networking.k8s.io里；
> - Deployment，DaemonSet，ReplicaSet分别在extensions和apps里；
> - Event分别在核心组（core group）和events.k8s.io里；

GVK和GVR是相互关联的。GVK在GVR标识的http路径下服务。关联GVK到GVR的映射过程称作REST映射。

>  `Resource` 是 `Kind` 在 API 中的标识，通常情况下 `Kind` 和 `Resource` 是一一对应的, 但是有时候相同的 `Kind` 可能对应多个 `Resources`, 比如 Scale Kind 可能对应很多 Resources：deployments/scale 或者 replicasets/scale, 但是在 CRD 中，每个 `Kind` 只会对应一种 `Resource`。
>
> `Scheme` 提供了 `GVK` 与对应 Go types(struct) 之间的映射

desired state

current status