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

创建`podWorkers`对象时，Kubelet用它自己的`syncPod`方法来初始化`syncPodFn`。然而，此方法仅用来做同步的准备工作。例如，它将上传最近的Pod状态到Apiserver，为Pod创建专有的目录，并为Pods获取所需的secrets。然后，Kubelet调用它自己containerRuntime的SyncPod方法来进行同步。containerRuntime抽象了Kubelet的底层容器运行，并定义了容器运行的各种接口。SyncPod就是其中之一。

Kubelet不执行任何容器相关的操作。Pod同步本质上是其状态的变更。实现容器状态变更必须调用、运行底层如PouchContainer等容器。

以下描述了containerRuntime的SyncPod方法来展示真正的同步操作：

```go
// kubernetes/pkg/kubelet/kuberuntime/kuberuntime_manager.go
func (m *kubeGenericRuntimeManager) SyncPod(pod *v1.Pod, _ v1.PodStatus, podStatus *kubecontainer.PodStatus, pullSecrets []v1.Secret, backOff *flowcontrol.Backoff) (result kubecontainer.PodSyncResult)
```

此函数首先调用`computePodActions(pod, podStatus)`来比对当前的Pod状态podStatus和目标Pod状态pod，计算需要的同步操作。计算完成之后，将返回如下所示的PodActions对象：

```go
// kubernetes/pkg/kubelet/kuberuntime/kuberuntime_manager.go
type podActions struct {
    KillPod bool
    
    CreateSandbox bool
    
    SandboxID string
    
    Attempt uint32
    
    ContainersToKill map[kubecontainer.ContainerID]containerToKillInfo
    
    NextInitContainerToStart *v1.Container
    
    ContainersToStart []int
}
```

PodActions实际上是一个操作列表：

1. 通常来说，KillPod和CreateSandbox的值是相同的，指定是否kill当前Pod sandbox（如果要创建一个新pod，则该操作为null）并创建一个新的sandbox；
2. SandboxID来辨识Pod创建操作。如果此值为null，则是第一次创建此Pod；若此值不为空，则在kill掉老的sandbox之后创建新的sandbox；
3. Attempt指定Pod重建sandbox的次数。初次创建Pod时，此值为0，它和SandboxID有相同的函数；
4. ContainersToKill辨识因配置变更或健康检测失败后需要被kill的Pod；
5. 如果运行中或者初始化过程中Pod的容器出现errors，NextInitContainerToStart指定接下来的初始化容器将被创建，创建并启动该init container，同步操作才算完成；
6. 若Pod sandbox已完成创建且init container也已完成，则根据ContainersToStart启动尚未运行的普通containers；

通过这样一个操作列表，剩下的SyncPod操作就简单了。即仅仅需要调用相关的底层container running接口来一步步执行新增或者删除操作来完成同步。

综述Pod的同步过程即是：当Pod的期望状态变更或者同步超时，则触发同步操作。同步就是比对当前container的状态和其期望状态，生成一个container启动/停止列表，并基于此列表调用底层container运行时接口启动或者停止container。

### 结论

如果container是一个进程，Kubelet则是一个面向container的进程监控。Kubelet的工作就是持续改变本地node的Pod运行状态以使其处于期望的状态。在转换过程中，不需要的container被删除并创建、配置新的container。现有container没有重复的修改、启动或停止操作。这就是所有关于Kubelet的核心处理逻辑。

### Note

1. The source code in this article is from Kubernetes v1.9.4, commit: bee2d1505c4fe820744d26d41ecd3fdd4a3d6546
2. For detailed comments about Kubernetes source code, visit [my GitHub page](https://github.com/YaoZengzeng/kubernetes).
3. Reference: [What even is a kubelet?](http://kamalmarhubi.com/blog/2015/08/27/what-even-is-a-kubelet/)







[Understanding the Kubelet Core Execution Frame](https://www.alibabacloud.com/blog/understanding-the-kubelet-core-execution-frame_593904)