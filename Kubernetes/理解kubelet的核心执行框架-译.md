> 本文基于kubelet源码着重分析了kubelet在Pod的生命周期管理过程中的方式。

`kubelet`在集群中是一个`node agent`的角色，负责`node`上`Pod`的生命周期管理。`kubelet`首先会获取`Pod`的配置到`node`，然后调用底层容器`runtime`（如`Docker`、`PouchContainer`等）来创建`Pod`。之后，`kubelet`会监控这些`Pod`，以确保其以期望的状态运行在`node`上。本文基于`kubelet`源码分析创建`Pod`之前的过程。

### 获取`Pod`配置

`kubelet`可以通过多种方式来获取`Pod`配置，最通用的方式就是通过`Apiserver`。另外，`kubelet`亦可以通过指定文件路径和访问具体的`http port`来获取指定Pod的配置。`kubelet`周期地访问指定文件路径和`http port`获取`Pod`配置来升级或者调整`node`上`Pod`状态。

在`kubelet`初始化过程中，会创建一个`PodConfig`对象，如下所示：

```go
// kubernetes/pkg/kubelet/config/config.go
type PodConfig struct {
    pods *podStorage
    mux  *config.Mux
    // the channel of denormalized changes passed to listeners
    updates chan kubetypes.PodUpdate
    ...
}
```

`PodConfig`本质上是一个`Pod`配置的复用器。内置的`mux`会监听各个Pod配置的来源（报错`Apiserver`、文件和`http`），并且周期地同步来源的`Pod`配置状态。`pods`缓存了来源的上次的`Pod`配置状态。在对比过配置后，`mux`会得到配置已变更的Pod，然后，`mux`根据变更类型对`Pod`进行分类，并在每个类型的`Pod`插入一个`PodUpdate`结构体：

```go
// kubernetes/pkg/kubelet/types/pod_update.go
type PodUpdate struct {
    Pods   []*v1.Pod
    Op     PodOperation
    Source string
}
```

`Op`字段定义了Pod的变更类型。



[Understanding the Kubelet Core Execution Frame](https://www.alibabacloud.com/blog/understanding-the-kubelet-core-execution-frame_593904)