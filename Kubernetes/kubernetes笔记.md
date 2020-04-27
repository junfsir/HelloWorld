### `SharedInformer`&`ListWatcher`

`Controller`通过`SharedInformer`监控`apiserver`中资源对象的状态变化，以此来缓解`apiserver`的压力，并提高效率；

`Controller`通过`ListWatcher`给`apiserver`发送一个查询后等待，当监控的资源对象有变化时，`apiserver`通过分块的`http`响应通知`Controller`；控制器看到`chunked`响应，会认为响应数据还没有发送完成，所以会持续等待；

在`kubernetes`内部提供了大量的`controller`，比如`node controller`，`pod controller`，`endpoint controller`等等；这些`controller`都是由`controller-manager`进行管理；每个`Controller`通过`API Server`提供的接口实时监控整个集群的每个资源对象的当前状态，当发生各种故障导致系统状态发生变化时，会尝试通过CRUD操作将系统状态修复到“期望状态”；在 `Kubernetes` 中，每个控制器只负责某种类型的特定资源；

kubernetes中结合watch请求增加了list请求，主要做如下两件事情:

watch请求开始之前，先发起一次list请求，获取集群中当前所有该类数据(同时得到最新的ResourceVersion)，之后基于最新的ResourceVersion发起watch请求。
当watch出错时(比如说网络闪断造成客户端和服务端数据不同步)，重新发起一次list请求获取所有数据，再重新基于最新ResourceVersion来watch。

kubernetes中基于ResourceVersion信息采用list-watch(http streaming)机制来保证组件间的数据实时可靠传送。

### `PLEG`

`Pod Lifecycle Event Generator`是`kubelet`中的一个模块，通过匹配`Pod`级别的事件来调整容器的运行时状态，并将调整的结果写入缓存，使`Pod`的缓存保持最新；

`Pod`的生命周期事件是在`Pod`层面上对底层容器状态变更的抽象，使其与底层的容器运行时无关，这样就可以让 `Kubelet` 不受底层容器运行时的影响；

[参考](https://fuckcloudnative.io/posts/understanding-the-pleg-is-not-healthy/)

### `StatefulSet Rolling Update`策略

`StatefulSet` 里的 `Pod` 采用和序号相反的顺序更新；在更新下一个 `Pod` 前，`StatefulSet Controller`终止每个 `Pod` 并等待它们变成 `Running` 和 `Ready`；请注意，虽然在顺序后继者变成 `Running` 和 `Ready` 之前 `StatefulSet` 控制器不会更新下一个 `Pod`，但它仍然会重建任何在更新过程中发生故障的 `Pod`， 使用的是它们当前的版本；已经接收到更新请求的 `Pod` 将会被恢复为更新的版本，没有收到请求的 `Pod` 则会被恢复为之前的版本；像这样，控制器尝试继续使应用保持健康并在出现间歇性故障时保持更新的一致性；

### `kubernetes crd`
一种资源就是`Kubernetes API`中的一个端点，它存储着某种API 对象的集合；自定义资源是对`Kubernetes API`的一种扩展，它对于每一个`Kubernetes`集群不一定可用；换句话说，它代表一个特定`Kubernetes`的定制化安装；在一个运行中的集群内，自定义资源可以通过动态注册出现和消失，集群管理员可以独立于集群本身更新自定义资源；一旦安装了自定义资源，用户就可以通过kubectl创建和访问他的对象，就像操作内建资源`pods`那样；

`CustomResourceDefinition (CRD)`是一个内建的`API`, 它提供了一个简单的方式来创建自定义资源；
部署一个`CRD`到集群中使`Kubernetes API`服务端开始为你指定的自定义资源服务；

### `Device Manager`&`Extended Resource`

`Device Manager`是Kubelet内负责Device Plugin交互和设备生命周期管理的模块；
`Extended Resource`: 一种自定义资源扩展的方式，将资源的名称和总数量上报给API server，而Scheduler则根据使用该资源pod的创建和删除，做资源可用量的加减法，进而在调度时刻判断是否有满足资源条件的节点。目前这里的Extended Resource的增加和减少单元必须是整数，比如你可以分配1个GPU，但是不能分配0.5个GPU；
`Device Plugin`：通过提供通用设备插件机制和标准的设备API接口。这样设备厂商只需要实现相应的API接口，无需修改Kubelet主干代码，就可以实现支持GPU、FPGA、高性能 NIC、InfiniBand 等各种设备的扩展；

### `Leader Election`

在`kubernetes`的`control plane components`，`kube-scheduler`和`kube-manager-controller`两个组件是有`leader`选举的，这个选举机制是k8s对于这两个组件的高可用保障；正常情况下`kube-scheduler`或`kube-manager-controller`组件的多个副本只有一个是处于业务逻辑运行状态，其它副本则不断的尝试去获取锁，去竞争`leader`，直到自己成为`leader`；如果正在运行的`leader`因某种原因导致当前进程退出，或者锁丢失，则由其它副本去竞争新的`leader`，获取leader继而执行业务逻辑；

`Leader Election` 的过程本质上就是一个竞争分布式锁的过程；在` Kubernetes` 中，这个分布式锁是以创建 `Endpoint` 或者` ConfigMap `资源的形式进行：谁先创建了某种资源，谁就获得锁；

```shell
# kubectl describe endpoints kube-controller-manager -nkube-system
Name:         kube-controller-manager
Namespace:    kube-system
Labels:       <none>
Annotations:  control-plane.alpha.kubernetes.io/leader={"holderIdentity":"docker22_87ded76c-a7df-11e9-8d4b-ead89f08374d","leaseDurationSeconds":15,"acquireTime":"2019-07-18T08:37:12Z","renewTime":"2019-07-18T09:01:...
Subsets:
Events:
  Type    Reason          Age   From                Message
  ----    ------          ----  ----                -------
  Normal  LeaderElection  24m   controller-manager  docker22_87ded76c-a7df-11e9-8d4b-ead89f08374d became leader
```

### `Kubernetes`健康检查

#### 方式

**READINESS**
设计 Readiness 探针的目的是用来让 Kubernetes 知道你的应用何时能对外提供服务。在服务发送流量到 Pod 之前，Kubernetes必须确保 Readinetes 探针检测成功。如果 Readiness 探针检测失败了，Kubernetes 会停掉 Pod 的流量，直到 Readiness 检测成功；

**LIVENESS**
Liveness 探针能让 Kubernetes 知道你的应用是否存活。如果你的应用是存活的，Kubernetes 不做任何处理。如果是挂掉的，Kubernetes 会移除异常的 Pod，并且启一个新的 Pod 替换它；

#### 作用

**READINESS**

假设你的应用需要时间进行预热和启动。即便进程已经启动，你的服务依然是不可用的，直到它真的运行起来。如果想让你的应用横向部署多实例，这也可能会导致一些问题。因为新的复本在没有完全准备好之前，不应该接收请求。但是默认情况下，只要容器内的进程启动完成，Kubernetes 就会开始发送流量过来。如果使用 Readiness 探针， Kubernetes 就会一直等待，直到应用完全启动，才会允许发送流量到新的复本；

**LIVENESS**

我们设想另外一种场景，你的应用产生了死锁，导致进程一直夯住，并且停止处理请求。因为进程还处在活跃状态，默认情况下， Kubernetes 认为一切正常，会继续向异常Pod 发送流量。通过使用 Liveness 探针， Kubernetes 会发现应用不再处理请求，然后重启异常的 Pod ；

#### 探针类型

**HTTP**

HTTP 可能是 Liveness 探针的最常用的实现方式。即便你的应用不是一个 HTTP 服务，你也可以通过在应用内部集成一个轻量级的HTTP 服务，以支持 Liveness 探针。Kubernetes 通过 ping 一个路径，如果 HTTP 响应的状态码是 2xx 或者 3xx ，说明该应用是健康状态，否则就是不健康状态；

**COMMAND**

对于命令行探针，kubernetes 在容器内运行命令，如果返回0，说明服务是健康状态，否则就是不健康状态。当你不能或者不想提供额外的 HTTP 服务，但是能使用命令行的时候，通过命令行来进行健康检查很有用的；

**TCP**

最后一种是 TCP 探针。Kubernetes 尝试跟某个端口建立一个 TCP 连接。如果能建立连接，表示容器是健康状态，否则是不健康状态；
假如 HTTP 和命令行都不能使用的情况下， TCP 的方式就派上用场了。例如 gRPC[6]或者 FTP 服务中，TCP 类型就是首选；

