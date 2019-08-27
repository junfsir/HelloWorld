> 本文基于kubelet源码着重分析了kubelet在Pod的生命周期管理过程中的方式。

`kubelet`在集群中扮演了`node agent`的角色，负责管理`node`上`Pod`的生命周期。其会首先获取`Pod`配置到`node`，然后调用底层容器`runtime`（如`Docker`、`PouchContainer`等）来创建`Pod`。之后，`kubelet`会监控这些`Pod`，以确保其以期望的状态运行在`node`上。本文基于`kubelet`源码分析创建`Pod`之前的过程。

### 获取`Pod`配置

`kubelet`可以通过多种方式来获取`Pod`配置，最通用的方式就是通过`Apiserver`。另外，亦可通过指定文件路径和访问具体的`http port`来获取Pod的配置。`kubelet`周期性访问指定文件路径和`http port`获取`Pod`配置来升级或者调整`node`上`Pod`状态。

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

`PodConfig`本质上是一个`Pod`配置的复用器。内置的`mux`会监听各个Pod配置的来源（包括`Apiserver`、文件和`http`），并且周期性同步来源的`Pod`配置状态。`pods`缓存了来源的最近一次`Pod`的配置状态。在比对配置后，`mux`会得到配置已变更的Pod，然后，`mux`根据变更类型对`Pod`进行分类，并在每个类型的`Pod`插入一个`PodUpdate`结构体：

```go
// kubernetes/pkg/kubelet/types/pod_update.go
type PodUpdate struct {
    Pods   []*v1.Pod
    Op     PodOperation
    Source string
}
```

`Op`字段定义了Pod的变更类型。举例来说，它的值可以是`ADD`或者`REMOVE`，表明具体操作是新增或者删除`Pods`定义中的`Pod`。最终，所有类型的`PodUpdate`都将被插入到`PodConfig`的`updates`。因此，我们只要监听`updates`通道就可以获取该`node`已变更的`Pod`配置。

### Pod同步

`kubelet`完成初始化之后，如下所述的`syncLoop`函数将会被调用：

 ```go
// kubernetes/pkg/kubelet/kubelet.go
// syncLoop is the main loop for processing changes. It watches for changes from
// three channels (file, apiserver, and http) and creates a union of them. For
// any new change seen, will run a sync against desired state and running state. If
// no changes are seen to the configuration, will synchronize the last known desired
// state every sync-frequency seconds. Never returns.
func (kl *Kubelet) syncLoop(updates <-chan kubetypes.PodUpdate, handler SyncHandler){
    ...
    for {
        if !kl.syncLoopIteration(...) {
            break
        }        
    }
    ...
}
 ```

注释表明，`syncLoop`函数是kubelet的主循环。该函数监听`updates`，来获取最近的`Pod`配置，并同步`Pod`的运行状态和期望状态。通过这种方式，所有运行在该`node`上的`Pod`都将运行在期望的状态。事实上，`syncLoop`只封装了`syncLoopIteration`，同步操作由`syncLoopIteration`来执行。

```go
// kubernetes/pkg/kubelet/kubelet.go
func (kl *Kubelet) syncLoopIteration(configCh <-chan kubetypes.PodUpdate ......) bool {
    select {
    case u, open := <-configCh:
        switch u.Op {
        case kubetypes.ADD:
            handler.HandlePodAdditions(u.Pods)
        case kubetypes.UPDATE:
            handler.HandlePodUpdates(u.Pods)
        ...
        }
    case e := <-plegCh:
        ...
        handler.HandlePodSyncs([]*v1.Pod{pod})
        ...
    case <-syncCh:
        podsToSync := kl.getPodsToSync()
        if len(podsToSync) == 0 {
            break
        }
        handler.HandlePodSyncs(podsToSync)
    case update := <-kl.livenessManager.Updates():
        if update.Result == proberesults.Failure {
            ...
            handler.HandlePodSyncs([]*v1.Pod{pod})
        }
    case <-housekeepingCh:
         ...
        handler.HandlePodCleanups()
        ...
    }
}
```





[Understanding the Kubelet Core Execution Frame](https://www.alibabacloud.com/blog/understanding-the-kubelet-core-execution-frame_593904)