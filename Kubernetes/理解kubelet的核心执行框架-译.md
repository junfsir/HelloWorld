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

`syncLoopIteration`函数有一个简单的处理逻辑，监听多个通道。一旦从通道获取到事件类型，就调用相关函数去处理事件，以下是对不同事件的处理：

1. 从`configCh`获取`Pod`配置变更，然后基于变更类型调用相关函数。例如，如果新`Pods`绑定到本地节点，则将调用`HandlePodAdditions`函数来处理这些`Pods`；如果某些`Pods`的配置发生变更，则调用`HandlePodUpdates`函数来升级这些`Pods`；
2. 如果容器的状态发生变更（如一个新容器被创建、启动），`PodlifecycleEvent`将发送到`plegCh`通道。事件包括`ContainerStarted`、容器ID以及容器所属`Pod`的ID等类型。然后，`SyncLoopIteration`将调用`HandlePodSyncs`来同步`Pod`配置；
3. `syncCh`实际上是一个计时器，默认情况下，`kubelet`每秒会触发该计时器来同步`Pod`的配置。
4. 在初始化过程中，`kubelet`会创建一个`livenessManager`来检查所有已配置`Pod`的健康状态。如果`kubelet`检查到`Pod`运行错误，会调用`HandlePodSyncs`同步`Pod`。此部分会在后面详述；
5. `houseKeepingCh` 也是一个计时器。默认情况下，`kubelet`每2秒触发一次并调用`HandlePodCleanups` 函数进行处理。这是一种以一定间隔回收已停止`Pod`资源的周期清理机制；

![](https://yqintl.alicdn.com/5920b65f95519c9400e2e5bddded1b9a2f7c7f3f.png)

如上图所示，多数处理函数的执行路径是类似的，包括`HandlePodAdditions`, `HandlePodUpdates`，而且`HandlePodSyncs`在完成自己的操作后会调用`dispatchWork`。若`dispatchWork`函数检测到`Pod`是非`Terminated`状态且需要同步，会调用`podWorkers`的`Update`方法来升级`Pod`。我们可以将`Pod`的创建、更新或同步过程视为从运行到期望状态的转换，以此来帮我们理解`Pod`的升级和同步过程。拿`Pod`的创建来说，我们可以认为新`Pod`的当前状态是空的，并且也可以认为是一个状态转换过程。因此，在`Pod`创建、更新或同步过程中，只用通过调用`Update`函数才能将`Pod`的状态可以变更到目标状态。

`podWorkers`创建于初始化过程中，如下所示：

```go
// kubernetes/pkg/kubelet/pod_workers.go
type podWorkers struct {
    ...
    podUpdates map[types.UID]chan UpdatePodOptions

    isWorking map[types.UID]bool

    lastUndeliveredWorkUpdate map[types.UID]UpdatePodOptions

    workQueue queue.WorkQueue

    syncPodFn syncPodFnType
    
    podCache kubecontainer.Cache
    ...
}
```

`kubelet`为每个已创建的`Pod`配置了一个`pod worker`，其本质上是一个`goroutine`，其创建了一个`buffer size`为1且类型为`UpdatePodOptions（Pod更新事件）`的`channel`，监听该`channel`来获取pod更新事件，并且调用在`podWorkers`的`syncPodFn`字段中的特定函数来执行同步。

另外，`pod worker`注册`channel`到`podWorkers`的`podUpdates map`中，以便指定的更新事件可以发送到相应的`pod worker`进行处理。

如果正在处理当前事件过程中又产生了其他的更新事件，那会发生什么呢？`podWorkers`将最近的事件缓存到`lastUndeliveresWorkUpdate`，然后在处理完当前事件后便立即进行处理。

每次处理更新事件时，`pod worker`都会将处理后的Pod添加到`podWorkers`的`workQueue`，并插入额外的延时。只有在延时到期时，才会在队列中检索`pod`，并执行下一次同步操作。之前已经提到，`syncCh`每秒触发一次来收集需要在当前节点上同步的`Pod`，然后调用`HandlePodSyncs`来执行同步。这些`Pod`在当前时间点过期并从`workQueue`中获取。然后，整个`pod`同步过程形成一个环，如下所示：

![](https://yqintl.alicdn.com/40480a1dd8d0ead1bbc17e11d5c2a47fcbccf5c5.png)











[Understanding the Kubelet Core Execution Frame](https://www.alibabacloud.com/blog/understanding-the-kubelet-core-execution-frame_593904)