## [Kubelet PLEG源码分析]( https://my.oschina.net/jxcdwangtao/blog/2253578 )

> [xidianwangtao@gmail.com](mailto:xidianwangtao@gmail.com)

> 摘要：PLEG(Pod Lifecycle Event Generator)是kubelet的核心模块，在kubelet/docker相关的许多问题定位时，我们经常能看到PLEG的异常日志。通过对PLEG的源码分析，希望能让大家了解PLEG是干什么的，以及它是如何工作的、它与什么模块有交互等问题。

------

> Based on Kubernetes 1.11.4

## NewMainKubelet --> New GenericPLEG

**Q: GenericPLEG在哪里创建的？**

**A: 同其他Manager类似，PLEG在kubelet调用NewMainKubelet进行初始化时创建的。**

```
// Capacity of the channel for receiving pod lifecycle events. This number
// is a bit arbitrary and may be adjusted in the future.
plegChannelCapacity = 1000
	
	// Generic PLEG relies on relisting for discovering container events.
// A longer period means that kubelet will take longer to detect container
// changes and to update pod status. On the other hand, a shorter period
// will cause more frequent relisting (e.g., container runtime operations),
// leading to higher cpu usage.
// Note that even though we set the period to 1s, the relisting itself can
// take more than 1s to finish if the container runtime responds slowly
// and/or when there are many container changes in one cycle.
plegRelistPeriod = time.Second * 1

pkg/kubelet/kubelet.go:692

func NewMainKubelet(...) (*Kubelet, error) {
	...
	klet.pleg = pleg.NewGenericPLEG(klet.containerRuntime, plegChannelCapacity, plegRelistPeriod, klet.podCache, clock.RealClock{})
	...
}	
```

- 通过调用pleg.NewGenericPLEG完成创建；
- plegChannelCapacity是存放PodLifecycleEvent的channel容量，不可配，写死为1000；
- PLEG relist进行循环检查的间隔，不可配，写死为1s；

下面是GenericPLEG的结构体定义：

```
pkg/kubelet/pleg/generic.go:49
// GenericPLEG is an extremely simple generic PLEG that relies solely on
// periodic listing to discover container changes. It should be used
// as temporary replacement for container runtimes do not support a proper
// event generator yet.
//
// Note that GenericPLEG assumes that a container would not be created,
// terminated, and garbage collected within one relist period. If such an
// incident happens, GenenricPLEG would miss all events regarding this
// container. In the case of relisting failure, the window may become longer.
// Note that this assumption is not unique -- many kubelet internal components
// rely on terminated containers as tombstones for bookkeeping purposes. The
// garbage collector is implemented to work with such situations. However, to
// guarantee that kubelet can handle missing container events, it is
// recommended to set the relist period short and have an auxiliary, longer
// periodic sync in kubelet as the safety net.
type GenericPLEG struct {
	// The period for relisting.
	relistPeriod time.Duration
	// The container runtime.
	runtime kubecontainer.Runtime
	// The channel from which the subscriber listens events.
	eventChannel chan *PodLifecycleEvent
	// The internal cache for pod/container information.
	podRecords podRecords
	// Time of the last relisting.
	relistTime atomic.Value
	// Cache for storing the runtime states required for syncing pods.
	cache kubecontainer.Cache
	// For testability.
	clock clock.Clock
	// Pods that failed to have their status retrieved during a relist. These pods will be
	// retried during the next relisting.
	podsToReinspect map[types.UID]*kubecontainer.Pod
}
```

- eventChannel: PLEG产生的PodLifecycleEvent要发送的Channel；

- podRecords: map[types.UID]*podRecord，其中key为PodID，value为podRecord：

  ```
  	type podRecord struct {
  		old     *kubecontainer.Pod
  		current *kubecontainer.Pod
  	}
  ```

- cache: kubecontainer.Cache,是记录kubelet存放的PodStatus及PodLifecycleEvent的subscribers

  - kubelet podworkers是subscriber。

- podsToReinspect: map[types.UID]*kubecontainer.Pod，用于保存那些relist失败的pods，待下次relist时会去遍历podsToReinspect中的Pods再次update cache;

  - updateCache会inspect pod并更新cache，如果inspect pod失败，则会被加入到podsToReinspect中；

## Kubelet.Run --> PLEG.Start

**Q: 在kubelet初始化时完成了PLEG的创建，那么合适启动的PLEG呢？**

**A: kubelet Run方法中会启动大量managers，PLEG的启动也在此时。**

```
pkg/kubelet/kubelet.go:1326

// Run starts the kubelet reacting to config updates
func (kl *Kubelet) Run(updates <-chan kubetypes.PodUpdate) {
	if kl.logServer == nil {
		kl.logServer = http.StripPrefix("/logs/", http.FileServer(http.Dir("/var/log/")))
	}
	if kl.kubeClient == nil {
		glog.Warning("No api server defined - no node status update will be sent.")
	}

	// Start the cloud provider sync manager
	if kl.cloudResourceSyncManager != nil {
		go kl.cloudResourceSyncManager.Run(wait.NeverStop)
	}

	if err := kl.initializeModules(); err != nil {
		kl.recorder.Eventf(kl.nodeRef, v1.EventTypeWarning, events.KubeletSetupFailed, err.Error())
		glog.Fatal(err)
	}

	// Start volume manager
	go kl.volumeManager.Run(kl.sourcesReady, wait.NeverStop)

	if kl.kubeClient != nil {
		// Start syncing node status immediately, this may set up things the runtime needs to run.
		go wait.Until(kl.syncNodeStatus, kl.nodeStatusUpdateFrequency, wait.NeverStop)
	}
	go wait.Until(kl.updateRuntimeUp, 5*time.Second, wait.NeverStop)

	// Start loop to sync iptables util rules
	if kl.makeIPTablesUtilChains {
		go wait.Until(kl.syncNetworkUtil, 1*time.Minute, wait.NeverStop)
	}

	// Start a goroutine responsible for killing pods (that are not properly
	// handled by pod workers).
	go wait.Until(kl.podKiller, 1*time.Second, wait.NeverStop)

	// Start component sync loops.
	kl.statusManager.Start()
	kl.probeManager.Start()

	// Start the pod lifecycle event generator.
	kl.pleg.Start()
	kl.syncLoop(updates, kl)
}
```

- 在kubelet开始syncLoop前启动PLEG；

## PLEG Start

PLEG Start就是启动一个协程，每个relistPeriod(1s)就调用一次relist，根据最新的PodStatus生成PodLiftCycleEvent。

```
pkg/kubelet/pleg/generic.go:130

// Start spawns a goroutine to relist periodically.
func (g *GenericPLEG) Start() {
	go wait.Until(g.relist, g.relistPeriod, wait.NeverStop)
}
```

## PLEG relist

relist是PLEG的核心，它从container runtime中查询属于kubelet管理的containers/sandboxes的信息，生成最新的PodStatus，然后对比podRecords中记录的Old PodStatus生成PodLifeCycleEvents，并发送到PLE Channel。

```
pkg/kubelet/pleg/generic.go:183

// relist queries the container runtime for list of pods/containers, compare
// with the internal pods/containers, and generates events accordingly.
func (g *GenericPLEG) relist() {
	glog.V(5).Infof("GenericPLEG: Relisting")

	if lastRelistTime := g.getRelistTime(); !lastRelistTime.IsZero() {
		metrics.PLEGRelistInterval.Observe(metrics.SinceInMicroseconds(lastRelistTime))
	}

	timestamp := g.clock.Now()
	defer func() {
		metrics.PLEGRelistLatency.Observe(metrics.SinceInMicroseconds(timestamp))
	}()

	// Get all the pods.
	podList, err := g.runtime.GetPods(true)
	if err != nil {
		glog.Errorf("GenericPLEG: Unable to retrieve pods: %v", err)
		return
	}

	g.updateRelistTime(timestamp)

	pods := kubecontainer.Pods(podList)
	g.podRecords.setCurrent(pods)

	// Compare the old and the current pods, and generate events.
	eventsByPodID := map[types.UID][]*PodLifecycleEvent{}
	for pid := range g.podRecords {
		oldPod := g.podRecords.getOld(pid)
		pod := g.podRecords.getCurrent(pid)
		// Get all containers in the old and the new pod.
		allContainers := getContainersFromPods(oldPod, pod)
		for _, container := range allContainers {
			events := computeEvents(oldPod, pod, &container.ID)
			for _, e := range events {
				updateEvents(eventsByPodID, e)
			}
		}
	}

	var needsReinspection map[types.UID]*kubecontainer.Pod
	if g.cacheEnabled() {
		needsReinspection = make(map[types.UID]*kubecontainer.Pod)
	}

	// If there are events associated with a pod, we should update the
	// podCache.
	for pid, events := range eventsByPodID {
		pod := g.podRecords.getCurrent(pid)
		if g.cacheEnabled() {
			// updateCache() will inspect the pod and update the cache. If an
			// error occurs during the inspection, we want PLEG to retry again
			// in the next relist. To achieve this, we do not update the
			// associated podRecord of the pod, so that the change will be
			// detect again in the next relist.
			// TODO: If many pods changed during the same relist period,
			// inspecting the pod and getting the PodStatus to update the cache
			// serially may take a while. We should be aware of this and
			// parallelize if needed.
			if err := g.updateCache(pod, pid); err != nil {
				glog.Errorf("PLEG: Ignoring events for pod %s/%s: %v", pod.Name, pod.Namespace, err)

				// make sure we try to reinspect the pod during the next relisting
				needsReinspection[pid] = pod

				continue
			} else if _, found := g.podsToReinspect[pid]; found {
				// this pod was in the list to reinspect and we did so because it had events, so remove it
				// from the list (we don't want the reinspection code below to inspect it a second time in
				// this relist execution)
				delete(g.podsToReinspect, pid)
			}
		}
		// Update the internal storage and send out the events.
		g.podRecords.update(pid)
		for i := range events {
			// Filter out events that are not reliable and no other components use yet.
			if events[i].Type == ContainerChanged {
				continue
			}
			g.eventChannel <- events[i]
		}
	}

	if g.cacheEnabled() {
		// reinspect any pods that failed inspection during the previous relist
		if len(g.podsToReinspect) > 0 {
			glog.V(5).Infof("GenericPLEG: Reinspecting pods that previously failed inspection")
			for pid, pod := range g.podsToReinspect {
				if err := g.updateCache(pod, pid); err != nil {
					glog.Errorf("PLEG: pod %s/%s failed reinspection: %v", pod.Name, pod.Namespace, err)
					needsReinspection[pid] = pod
				}
			}
		}

		// Update the cache timestamp.  This needs to happen *after*
		// all pods have been properly updated in the cache.
		g.cache.UpdateTime(timestamp)
	}

	// make sure we retain the list of pods that need reinspecting the next time relist is called
	g.podsToReinspect = needsReinspection
}
```

- 通过runtime获取所有本机所有PodList，并设置给podRecord的Current Pods；
- 聚合Current和Old Pods中的所有Containers进行遍历，根据CurrentPod,OldPod,ConainerID生成PodLifecycleEvents；

```
pkg/kubelet/pleg/generic.go:317
func computeEvents(oldPod, newPod *kubecontainer.Pod, cid *kubecontainer.ContainerID) []*PodLifecycleEvent {
	var pid types.UID
	if oldPod != nil {
		pid = oldPod.ID
	} else if newPod != nil {
		pid = newPod.ID
	}
	oldState := getContainerState(oldPod, cid)
	newState := getContainerState(newPod, cid)
	return generateEvents(pid, cid.ID, oldState, newState)
}

pkg/kubelet/pleg/generic.go:143
func generateEvents(podID types.UID, cid string, oldState, newState plegContainerState) []*PodLifecycleEvent {
	if newState == oldState {
		return nil
	}

	glog.V(4).Infof("GenericPLEG: %v/%v: %v -> %v", podID, cid, oldState, newState)
	switch newState {
	case plegContainerRunning:
		return []*PodLifecycleEvent{{ID: podID, Type: ContainerStarted, Data: cid}}
	case plegContainerExited:
		return []*PodLifecycleEvent{{ID: podID, Type: ContainerDied, Data: cid}}
	case plegContainerUnknown:
		return []*PodLifecycleEvent{{ID: podID, Type: ContainerChanged, Data: cid}}
	case plegContainerNonExistent:
		switch oldState {
		case plegContainerExited:
			// We already reported that the container died before.
			return []*PodLifecycleEvent{{ID: podID, Type: ContainerRemoved, Data: cid}}
		default:
			return []*PodLifecycleEvent{{ID: podID, Type: ContainerDied, Data: cid}, {ID: podID, Type: ContainerRemoved, Data: cid}}
		}
	default:
		panic(fmt.Sprintf("unrecognized container state: %v", newState))
	}
}
```

- New/Old plegContainerState与PodLifecycleEvent的映射关系如下图：

![img](https://oscimg.oschina.net/oscnet/c57df569921f9a0a9ab639bbae2139e5465.jpg)

- 遍历生成的PodLifecycleEvents，调用updateCache：
  - 通过runtime查询当前PodStatus（包括Pod对应的所有containerStatues，sandboxStatuses）；
  - 将PodStatus更新到cache中；
- 如果updateCache失败，则将该Pod重新加入到podsToReinspect，待下次relist时会遍历podsToReinspect中的Pods，再次调用updateCache。
- 如果updateCache成功，则检查该Pod是否已经在podsToReinspect中，如果存在，则从podsToReinspect中删除给Pod；
- uodateCache成功后，更新podRecords（Current赋值给Old，Current设为nil），并将非ContainerChanged类型的PodLifecycleEvent发送到eventChannel中；
  - ContainerChanged类型的Event已经被Disabled；
- 遍历podsToReinspect中的Pods，调用updateCache更新cache，如果updateCache失败，则仍然重新放回到podsToReinspect中待下次relist。

## Kubelet SycnLoop

**Q: PodLifecycleEvent是发送到eventChannel了了，谁拿去用了呢？**

**A: kubelet syncLoop!!!**

kubelet syncLoop是kubelet来维护Pod状态的核心逻辑，每次sync都会检查Pod的状态并进行修复。

```
func (kl *Kubelet) syncLoop(updates <-chan kubetypes.PodUpdate, handler SyncHandler) {
	glog.Info("Starting kubelet main sync loop.")
	// The resyncTicker wakes up kubelet to checks if there are any pod workers
	// that need to be sync'd. A one-second period is sufficient because the
	// sync interval is defaulted to 10s.
	syncTicker := time.NewTicker(time.Second)
	defer syncTicker.Stop()
	housekeepingTicker := time.NewTicker(housekeepingPeriod)
	defer housekeepingTicker.Stop()
	plegCh := kl.pleg.Watch()
	const (
		base   = 100 * time.Millisecond
		max    = 5 * time.Second
		factor = 2
	)
	duration := base
	for {
		if rs := kl.runtimeState.runtimeErrors(); len(rs) != 0 {
			glog.Infof("skipping pod synchronization - %v", rs)
			// exponential backoff
			time.Sleep(duration)
			duration = time.Duration(math.Min(float64(max), factor*float64(duration)))
			continue
		}
		// reset backoff if we have a success
		duration = base

		kl.syncLoopMonitor.Store(kl.clock.Now())
		if !kl.syncLoopIteration(updates, handler, syncTicker.C, housekeepingTicker.C, plegCh) {
			break
		}
		kl.syncLoopMonitor.Store(kl.clock.Now())
	}
}
```

- syncLoop调用pleg.Watch()返回PodLifecycleEvent Channel。
- syncLoop中死循环的调用syncLoopIteration进行每次迭代修复。
- syncLoopIteration方法中一个重要的参数就是pleg channel，syncLoopIteration会从pleg channel中获取PodLifecycleEvent进行消费。

```
pkg/kubelet/kubelet.go:1796

func (kl *Kubelet) syncLoopIteration(configCh <-chan kubetypes.PodUpdate, handler SyncHandler,
	syncCh <-chan time.Time, housekeepingCh <-chan time.Time, plegCh <-chan *pleg.PodLifecycleEvent) bool {
	select {
	case u, open := <-configCh:
		...
	case e := <-plegCh:
		if isSyncPodWorthy(e) {
			// PLEG event for a pod; sync it.
			if pod, ok := kl.podManager.GetPodByUID(e.ID); ok {
				glog.V(2).Infof("SyncLoop (PLEG): %q, event: %#v", format.Pod(pod), e)
				handler.HandlePodSyncs([]*v1.Pod{pod})
			} else {
				// If the pod no longer exists, ignore the event.
				glog.V(4).Infof("SyncLoop (PLEG): ignore irrelevant event: %#v", e)
			}
		}

		if e.Type == pleg.ContainerDied {
			if containerID, ok := e.Data.(string); ok {
				kl.cleanUpContainersInPod(e.ID, containerID)
			}
		}
	case <-syncCh:
		...
	case update := <-kl.livenessManager.Updates():
		...
	case <-housekeepingCh:
		...
	return true
}
```

syncLoopIteration会从config channel, pleg channel, sync channel, housekeeping channel中获取信息，然后就行消费。我们主要看pleg channel的分支：

- 如果**`eventType != ContainerRemoved`**，那么会根据event中PodID从pod manager中获取Pod对象；
  - 然后嗲都用handler.HandlePodSyncs将该pod dispatchWork到对应的pod worker进行UpdatePod操作；
  - podWorkers.UpdatePod会封装UpdatePodOptions对象并发送到UpdatePodOptions Channel；
  - kubelet syncPod从UpdatePodOptions Channel中获取UpdatePodOptions对象进行**Pod sync**操作；
- 如果**`eventType == ContainerDied`**，则从event.Data中获取containerID；
  - 然后调用cleanUpContainersInPod将ContainerID发动到podContainerDeletor Channel；
  - Kubelet podContainerDeletor负责消费podContainerDeletor Channel中的ContainerID；
  - podContainerDeletor调用KubeGenericRuntimeManager.removeContainer启动容器remove流程：
    - 如果enable了CPU Manager Policy，那么先通过internalLifecycle.PostStopContainer调用CPU Manager对该Container占用的cpus进行释放；
    - 然后调用KubeGenericRuntimeManager.removeContainerLog将`/var/logs/containrs/`及`/var/log/pods/`中对应该containerID的log删除；
    - 最后调用docker**删除该container**。

**Q: kubelet如何过滤本机containers中非k8s管理的container？**

**A: kubelet通过以下Label Filter找出k8s管理的container sandbox**

- "io.kubernetes.docker.type": "container"

**Q: kubelet是如何关联Pod和Container的？**

**A: 通过给container打上如下Label，标识对应的Pod**

- "io.kubernetes.pod.name": "xxx"
- "io.kubernetes.pod.uid": "xxxxxx"

**Q: kubelet管理的container，都打了哪些Label?**

**A: Sample如下：**

```
"annotation.io.kubernetes.container.hash": "b7c1651a",
"annotation.io.kubernetes.container.ports": "[{\"name\":\"web\",\"containerPort\":80,\"protocol\":\"TCP\"}]",
"annotation.io.kubernetes.container.restartCount": "0",
"annotation.io.kubernetes.container.terminationMessagePath": "/dev/termination-log",
"annotation.io.kubernetes.container.terminationMessagePolicy": "File",
"annotation.io.kubernetes.pod.terminationGracePeriod": "10",
"io.kubernetes.container.logpath": "/var/log/pods/381f8cc6-d84a-11e8-b596-5254000a5151/nginx/0.log",
"io.kubernetes.container.name": "nginx",
"io.kubernetes.docker.type": "container",
"io.kubernetes.pod.name": "web-0",
"io.kubernetes.pod.namespace": "default",
"io.kubernetes.pod.uid": "381f8cc6-d84a-11e8-b596-5254000a5151",
"io.kubernetes.sandbox.id": "cc3be54bf8e9bd386423d23eaccfd2f05e8be2156d60f933791a25c261c8d8a8"
```

## PLEG Core Logic Diagram

> 注: 绿色图块表示与PLEG有交互的kubelet模块。

![img](https://oscimg.oschina.net/oscnet/a81b99467882f2be2c990b1aed4da3b2e13.jpg)

## 总结

PLEG是kubelet的一个核心模块，它维护着一块cache（以pods信息为主），负责从runtime获取containers/sandboxes的信息，并根据前后两次信息对比，生成对应的PodLifecycleEvent，通过eventChannel发送到kubelet syncLoop进行消费，最终由kubelet syncPod完成Pod的同步，维护着用户的“期望”。通过对PLEG的分析，我们可以看到kubelet和docker之间的PodStatus和ContainerStatus的转换关系、Pod与Container之间的归属机制。