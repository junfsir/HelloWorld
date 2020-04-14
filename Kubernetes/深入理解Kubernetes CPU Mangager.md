### [深入理解 Kubernetes CPU Mangager](https://my.oschina.net/jxcdwangtao/blog/2874540)

> Author: [xidianwangtao@gmail.com](mailto:xidianwangtao@gmail.com)

> 摘要：Kuberuntime CPU Manager在我们生产环境中有大规模的应用，我们必须对其有深入理解，方能运筹帷幄。本文对CPU Manager的使用场景、使用方法、工作机制、可能存在的问题及解决办法等方面都有涉及，希望对大家有所帮助。

## CPU Manager是干什么的？

熟悉docker的用户，一定用过docker cpuset的能力，用来指定docker container启动时绑定指定的cpu和memory node。

```
--cpuset-cpus=""	CPUs in which to allow execution (0-3, 0,1)
--cpuset-mems=""	Memory nodes (MEMs) in which to allow execution (0-3, 0,1). Only effective on NUMA systems.
```

但是Kubernetes一直没有提供提供的能力，直到Kubernetes 1.8开始，Kubernetes提供了CPU Manager特性来支持cpuset的能力。从Kubernetes 1.10版本开始到目前的1.12，该特性还是Beta版。

CPU Manager是Kubelet CM中的一个模块，目标是通过给某些Containers绑定指定的cpus，达到绑定cpus的目标，从而提升这些cpu敏感型任务的性能。

## 什么场景下会考虑用CPU Manager？

前面提到CPU敏感型任务，会因为使用CpuSet而大幅度提升计算性能，那到底具备哪些特点的任务是属于CPU敏感型的呢？

- Sensitive to CPU throttling effects.
- Sensitive to context switches.
- Sensitive to processor cache misses.
- Benefits from sharing a processor resources (e.g., data and instruction caches).
- Sensitive to cross-socket memory traffic.
- Sensitive or requires hyperthreads from the same physical CPU core.

[Feature Highlight/ CPU Manager - Kubernetes](https://kubernetes.io/blog/2018/07/24/feature-highlight-cpu-manager/)中还列举了一些具体的Sample对比，有兴趣的可以去了解。我们公司的很多应用是属于这种类型的，而且cpuset带来的好处还有cpu资源结算的方便.当然，这几乎一定会带来整个集群的cpu利用率会有所降低，这就取决于你是否把应用的性能放在第一位了。

## 如何使用CPU Manager

在Kubernetes v1.8-1.9版本中，CPU Manager还是Alpha，在v1.10-1.12是Beta。我没关注过CPU Manager这几个版本的Changelog，还是建议在1.10之后的版本中使用。

### Enable CPU Manager

- 确保kubelet中CPUManager Feature Gate为true(BETA - default=true)
- 目前CPU Manager支持两种Policy，分别为none和static，通过kubelet `--cpu-manager-policy`设置，未来会增加dynamic policy做Container生命周期内的cpuset动态调整。
  - **none**: 为cpu manager的默认值，相当于没有启用cpuset的能力。cpu request对应到cpu share，cpu limit对应到cpu quota。
  - **static**: 目前，请设置`--cpu-manager-policy=static`来启用，kubelet将在Container启动前分配绑定的cpu set，分配时还会考虑cpu topology来提升cpu affinity，后面会提到。
- 确保kubelet为`--kube-reserved`和`--system-reserved`都配置了值，可以不是整数个cpu，最终会计算reserved cpus时会向上取整。这样做的目的是为了防止CPU Manager把Node上所有的cpu cores分配出去了，导致kubelet及系统进程都没有可用的cpu了。

> 注意CPU Manager还有一个配置项`--cpu-manager-reconcile-period`，用来配置CPU Manager Reconcile Kubelet内存中CPU分配情况到cpuset cgroups的修复周期。如果没有配置该项，那么将使用`--node-status-update-frequency（default 10s）`配置的值。

### Workload选项

完成了以上配置，就启用了Static CPU Manager，接下来就是在Workload中使用了。Kubernetes要求使用CPU Manager的Pod、Container具备以下两个条件：

- Pod QoS为Guaranteed；
- Pod中该Container的Cpu request必须为整数CPUs；

```
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      limits:
        memory: "200Mi"
        cpu: "2"
      requests:
        memory: "200Mi"
        cpu: "2"
```

任何其他情况下的Containers，CPU Manager都不会为其分配绑定的CPUs，而是通过CFS使用Shared Pool中的CPUs。Shared Pool中的CPU集，就是Node上`CPUCapacity - ReservedCPUs - ExclusiveCPUs`。

## CPU Manager工作流

CPU Manager为满足条件的Container分配指定的CPUs时，会尽量按照CPU Topology来分配，也就是考虑CPU Affinity，按照如下的优先顺序进行CPUs选择：（Logic CPUs就是Hyperthreads）

1. 如果Container请求的Logic CPUs数量不小于单块CPU Socket中Logci CPUs数量，那么会优先把整块CPU Socket中的Logic CPUs分配给该Container。
2. 如果Container剩余请求的Logic CPUs数量不小于单块物理CPU Core提供的Logic CPUs数量，那么会优先把整块物理CPU Core上的Logic CPUs分配给该Container。
3. Container剩余请求的Logic CPUs则从按照如下规则排好序的Logic CPUs列表中选择：
   - number of CPUs available on the same socket
   - number of CPUs available on the same core

```
pkg/kubelet/cm/cpumanager/cpu_assignment.go:149

func takeByTopology(topo *topology.CPUTopology, availableCPUs cpuset.CPUSet, numCPUs int) (cpuset.CPUSet, error) {
	acc := newCPUAccumulator(topo, availableCPUs, numCPUs)
	if acc.isSatisfied() {
		return acc.result, nil
	}
	if acc.isFailed() {
		return cpuset.NewCPUSet(), fmt.Errorf("not enough cpus available to satisfy request")
	}

	// Algorithm: topology-aware best-fit
	// 1. Acquire whole sockets, if available and the container requires at
	//    least a socket's-worth of CPUs.
	for _, s := range acc.freeSockets() {
		if acc.needs(acc.topo.CPUsPerSocket()) {
			glog.V(4).Infof("[cpumanager] takeByTopology: claiming socket [%d]", s)
			acc.take(acc.details.CPUsInSocket(s))
			if acc.isSatisfied() {
				return acc.result, nil
			}
		}
	}

	// 2. Acquire whole cores, if available and the container requires at least
	//    a core's-worth of CPUs.
	for _, c := range acc.freeCores() {
		if acc.needs(acc.topo.CPUsPerCore()) {
			glog.V(4).Infof("[cpumanager] takeByTopology: claiming core [%d]", c)
			acc.take(acc.details.CPUsInCore(c))
			if acc.isSatisfied() {
				return acc.result, nil
			}
		}
	}

	// 3. Acquire single threads, preferring to fill partially-allocated cores
	//    on the same sockets as the whole cores we have already taken in this
	//    allocation.
	for _, c := range acc.freeCPUs() {
		glog.V(4).Infof("[cpumanager] takeByTopology: claiming CPU [%d]", c)
		if acc.needs(1) {
			acc.take(cpuset.NewCPUSet(c))
		}
		if acc.isSatisfied() {
			return acc.result, nil
		}
	}

	return cpuset.NewCPUSet(), fmt.Errorf("failed to allocate cpus")
}
```

### Discovering CPU topology

CPU Manager能正常工作的前提，是发现Node上的CPU Topology，Discovery这部分工作是由cAdvisor完成的。

在cAdvisor的MachineInfo中通过Topology会记录cpu和mem的Topology信息。其中Topology的每个Node对象就是对应一个CPU Socket。

```
vendor/github.com/google/cadvisor/info/v1/machine.go

type MachineInfo struct {
	// The number of cores in this machine.
	NumCores int `json:"num_cores"`

	...

	// Machine Topology
	// Describes cpu/memory layout and hierarchy.
	Topology []Node `json:"topology"`

	...
}

type Node struct {
	Id int `json:"node_id"`
	// Per-node memory
	Memory uint64  `json:"memory"`
	Cores  []Core  `json:"cores"`
	Caches []Cache `json:"caches"`
}
```

cAdvisor通过GetTopology来完成信息的构建，主要是通过提取`/proc/cpuinfo`中信息来完成CPU Topology，通过读取`/sys/devices/system/cpu/cpu`来获取cpu cache信息。

```
vendor/github.com/google/cadvisor/machine/machine.go

func GetTopology(sysFs sysfs.SysFs, cpuinfo string) ([]info.Node, int, error) {
	nodes := []info.Node{}

	...
	return nodes, numCores, nil
}
```

下面是一个典型的NUMA CPU Topology结构：

![img](https://oscimg.oschina.net/oscnet/3c353b2e715f36bc61c733c822ee75b399c.jpg)

### 创建容器

对于满足前面提到的满足static policy的Container创建时，kubelet会为其按照约定的cpu affinity来为其挑选最优的CPU Set。Container的创建时CPU Manager工作流程大致如下：

1. Kuberuntime调用容器运行时去创建该Container。
2. Kuberuntime将该Container交给CPU Manager处理。
3. CPU Manager为Container按照static policy逻辑进行处理。
4. CPU Manager从当前Shared Pool中挑选“最佳”Set拓扑结构的CPU，对于不满足Static Policy的Contianer，则返回Shared Pool中所有CPUS组成的Set。
5. CPU Manager将对该Container的CPUs分配情况记录到Checkpoint State中，并且从Shared Pool中删除刚分配的CPUs。
6. CPU Manager再从state中读取该Container的CPU分配信息，然后通过UpdateContainerResources cRI接口将其更新到Cpuset Cgroups中，包括对于非Static Policy Container。
7. Kuberuntime调用容器运行时Start该容器。

```
func (m *manager) AddContainer(p *v1.Pod, c *v1.Container, containerID string) error {
	m.Lock()
	err := m.policy.AddContainer(m.state, p, c, containerID)
	if err != nil {
		glog.Errorf("[cpumanager] AddContainer error: %v", err)
		m.Unlock()
		return err
	}
	cpus := m.state.GetCPUSetOrDefault(containerID)
	m.Unlock()

	if !cpus.IsEmpty() {
		err = m.updateContainerCPUSet(containerID, cpus)
		if err != nil {
			glog.Errorf("[cpumanager] AddContainer error: %v", err)
			return err
		}
	} else {
		glog.V(5).Infof("[cpumanager] update container resources is skipped due to cpu set is empty")
	}

	return nil
}
```

### 删除容器

当这些通过CPU Manager分配CPUs的Container要Delete时，CPU Manager工作流大致如下：

1. Kuberuntime会调用CPU Manager去按照static policy中定义逻辑处理。
2. CPU Manager将该Container分配的Cpu Set重新归还到Shared Pool中。
3. Kuberuntime调用容器运行时Remove该容器。
4. CPU Manager会异步地进行Reconcile Loop，为使用Shared Pool中的Cpus的Containers更新CPU集合。

```
func (m *manager) RemoveContainer(containerID string) error {
	m.Lock()
	defer m.Unlock()

	err := m.policy.RemoveContainer(m.state, containerID)
	if err != nil {
		glog.Errorf("[cpumanager] RemoveContainer error: %v", err)
		return err
	}
	return nil
}
```

## Checkpoint

文件坏了，或者被删除了，该如何操作?

Note: CPU Manager doesn’t support offlining and onlining of CPUs at runtime. Also, if the set of online CPUs changes on the node, the node must be drained and CPU manager manually reset by deleting the state file cpu_manager_state in the kubelet root directory.

在Container Manager创建时，会顺带完成CPU Manager的创建。我们看看创建CPU Manager时做了什么？我们也就清楚了Kubelet重启时CPU Manager做了什么。

```
// NewManager creates new cpu manager based on provided policy
func NewManager(cpuPolicyName string, reconcilePeriod time.Duration, machineInfo *cadvisorapi.MachineInfo, nodeAllocatableReservation v1.ResourceList, stateFileDirectory string) (Manager, error) {
	var policy Policy

	switch policyName(cpuPolicyName) {

	case PolicyNone:
		policy = NewNonePolicy()

	case PolicyStatic:
		topo, err := topology.Discover(machineInfo)
		if err != nil {
			return nil, err
		}
		glog.Infof("[cpumanager] detected CPU topology: %v", topo)
		reservedCPUs, ok := nodeAllocatableReservation[v1.ResourceCPU]
		if !ok {
			// The static policy cannot initialize without this information.
			return nil, fmt.Errorf("[cpumanager] unable to determine reserved CPU resources for static policy")
		}
		if reservedCPUs.IsZero() {
			// The static policy requires this to be nonzero. Zero CPU reservation
			// would allow the shared pool to be completely exhausted. At that point
			// either we would violate our guarantee of exclusivity or need to evict
			// any pod that has at least one container that requires zero CPUs.
			// See the comments in policy_static.go for more details.
			return nil, fmt.Errorf("[cpumanager] the static policy requires systemreserved.cpu + kubereserved.cpu to be greater than zero")
		}

		// Take the ceiling of the reservation, since fractional CPUs cannot be
		// exclusively allocated.
		reservedCPUsFloat := float64(reservedCPUs.MilliValue()) / 1000
		numReservedCPUs := int(math.Ceil(reservedCPUsFloat))
		policy = NewStaticPolicy(topo, numReservedCPUs)

	default:
		glog.Errorf("[cpumanager] Unknown policy \"%s\", falling back to default policy \"%s\"", cpuPolicyName, PolicyNone)
		policy = NewNonePolicy()
	}

	stateImpl, err := state.NewCheckpointState(stateFileDirectory, cpuManagerStateFileName, policy.Name())
	if err != nil {
		return nil, fmt.Errorf("could not initialize checkpoint manager: %v", err)
	}

	manager := &manager{
		policy:                     policy,
		reconcilePeriod:            reconcilePeriod,
		state:                      stateImpl,
		machineInfo:                machineInfo,
		nodeAllocatableReservation: nodeAllocatableReservation,
	}
	return manager, nil
}
```

- 调用topology.Discover将cAdvisormachineInfo.Topology封装成CPU Manager管理的CPUTopology。
- 然后计算reservedCPUs（KubeReservedCPUs + SystemReservedCPUs + HardEvictionThresholds），并向上取整，最终最为reserved cpus。如果reservedCPUs为零，将返回Error，因为我们必须static policy必须要求System Reserved和Kube Reserved不为空。
- 调用NewStaticPolicy创建static policy，创建时会调用takeByTopology为reserved cpus按照static policy挑选cpus的逻辑选择对应的CPU Set，最终设置到StaticPolicy.reserved中(注意，并没有真正为reserved cpu set更新到cgroups，而是添加到Default CPU Set中，并且不被static policy Containers分配，这样Default CPU Set永远不会为空，它至少包含reserved CPU Set中的CPUs)。在AddContainer allocateCPUs计算assignableCPUs时，会除去这些reserved CPU Set。
- 接下来，调用state.NewCheckpointState，创建`cpu_manager_state` Checkpoint文件（如果存在，则不清空），初始Memory State，并从Checkpoint文件中restore到Memory State中。

`cpu_manager_state` Checkpoint文件内容就是CPUManagerCheckpoint结构体的json格式,其中Entries的key是ContainerID，value为该Container对应的Assigned CPU Set信息。

```
// CPUManagerCheckpoint struct is used to store cpu/pod assignments in a checkpoint
type CPUManagerCheckpoint struct {
	PolicyName    string            `json:"policyName"`
	DefaultCPUSet string            `json:"defaultCpuSet"`
	Entries       map[string]string `json:"entries,omitempty"`
	Checksum      checksum.Checksum `json:"checksum"`
}
```

接下来就是CPU Manager的启动了。

```
func (m *manager) Start(activePods ActivePodsFunc, podStatusProvider status.PodStatusProvider, containerRuntime runtimeService) {
	glog.Infof("[cpumanager] starting with %s policy", m.policy.Name())
	glog.Infof("[cpumanager] reconciling every %v", m.reconcilePeriod)

	m.activePods = activePods
	m.podStatusProvider = podStatusProvider
	m.containerRuntime = containerRuntime

	m.policy.Start(m.state)
	if m.policy.Name() == string(PolicyNone) {
		return
	}
	go wait.Until(func() { m.reconcileState() }, m.reconcilePeriod, wait.NeverStop)
}
```

- 启动static policy;
- 启动Reconcile Loop；

![img](https://oscimg.oschina.net/oscnet/417c9d20ec00e26f209fd900b6032a720f2.jpg)

## Reconcile Loop到底做了什么？

CPU Manager Reconcile按照`--cpu-manager-reconcile-period`配置的周期进行Loop，Reconcile注意进行如下处理:

- 遍历所有activePods中的所有Containers，注意包括InitContainers，对每个Container继续进行下面处理。
- 检查该ContainerID是否在CPU Manager维护的Memory State assignments中，
  - 如果不在Memory State assignments中：
    - 再检查对应的Pod.Status.Phase是否为Running且DeletionTimestamp为nil，如果是，则调用CPU Manager的AddContainer对该Container/Pod进行QoS和cpu request检查，如果满足static policy的条件，则调用takeByTopology为该Container分配“最佳”CPU Set，并写入到Memory State和Checkpoint文件(`cpu_manager_sate`)中，并继续后面流程。
    - 如果对应的Pod.Status.Phase是否为Running且DeletionTimestamp为nil为false，则跳过该Container，该Container处理结束。不满足static policy的Containers因为不在Memory State assignments中，所以对它们的处理流程也到此结束。
  - 如果ContainerID在CPU Manager assignments维护的Memory State中，继续后面流程。
- 然后从Memory State中获取该ContainerID对应的CPU Set。
- 最后调用CRI UpdateContainerCPUSet更新到cpuset cgroups中。

```
pkg/kubelet/cm/cpumanager/cpu_manager.go:219

func (m *manager) reconcileState() (success []reconciledContainer, failure []reconciledContainer) {
	success = []reconciledContainer{}
	failure = []reconciledContainer{}

	for _, pod := range m.activePods() {
		allContainers := pod.Spec.InitContainers
		allContainers = append(allContainers, pod.Spec.Containers...)
		for _, container := range allContainers {
			status, ok := m.podStatusProvider.GetPodStatus(pod.UID)
			if !ok {
				glog.Warningf("[cpumanager] reconcileState: skipping pod; status not found (pod: %s, container: %s)", pod.Name, container.Name)
				failure = append(failure, reconciledContainer{pod.Name, container.Name, ""})
				break
			}

			containerID, err := findContainerIDByName(&status, container.Name)
			if err != nil {
				glog.Warningf("[cpumanager] reconcileState: skipping container; ID not found in status (pod: %s, container: %s, error: %v)", pod.Name, container.Name, err)
				failure = append(failure, reconciledContainer{pod.Name, container.Name, ""})
				continue
			}

			// Check whether container is present in state, there may be 3 reasons why it's not present:
			// - policy does not want to track the container
			// - kubelet has just been restarted - and there is no previous state file
			// - container has been removed from state by RemoveContainer call (DeletionTimestamp is set)
			if _, ok := m.state.GetCPUSet(containerID); !ok {
				if status.Phase == v1.PodRunning && pod.DeletionTimestamp == nil {
					glog.V(4).Infof("[cpumanager] reconcileState: container is not present in state - trying to add (pod: %s, container: %s, container id: %s)", pod.Name, container.Name, containerID)
					err := m.AddContainer(pod, &container, containerID)
					if err != nil {
						glog.Errorf("[cpumanager] reconcileState: failed to add container (pod: %s, container: %s, container id: %s, error: %v)", pod.Name, container.Name, containerID, err)
						failure = append(failure, reconciledContainer{pod.Name, container.Name, containerID})
						continue
					}
				} else {
					// if DeletionTimestamp is set, pod has already been removed from state
					// skip the pod/container since it's not running and will be deleted soon
					continue
				}
			}

			cset := m.state.GetCPUSetOrDefault(containerID)
			if cset.IsEmpty() {
				// NOTE: This should not happen outside of tests.
				glog.Infof("[cpumanager] reconcileState: skipping container; assigned cpuset is empty (pod: %s, container: %s)", pod.Name, container.Name)
				failure = append(failure, reconciledContainer{pod.Name, container.Name, containerID})
				continue
			}

			glog.V(4).Infof("[cpumanager] reconcileState: updating container (pod: %s, container: %s, container id: %s, cpuset: \"%v\")", pod.Name, container.Name, containerID, cset)
			err = m.updateContainerCPUSet(containerID, cset)
			if err != nil {
				glog.Errorf("[cpumanager] reconcileState: failed to update container (pod: %s, container: %s, container id: %s, cpuset: \"%v\", error: %v)", pod.Name, container.Name, containerID, cset, err)
				failure = append(failure, reconciledContainer{pod.Name, container.Name, containerID})
				continue
			}
			success = append(success, reconciledContainer{pod.Name, container.Name, containerID})
		}
	}
	return success, failure
}
```

## Validate State

CPU Manager启动时，除了会启动一个goruntime进行Reconcile以外，还会对State进行validate处理:

- 当Memory State中Shared(Default) CPU Set为空时，CPU Assginments也必须为空，然后对Memory State中的Shared Pool进行初始化，并写入到Checkpoint文件中（初始化Checkpoint）。
- 只要我们没有手动去删Checkpoint文件，那么在前面提到的state.NewCheckpointState中会根据Checkpoint文件restore到Memory State中，因此之前Assgned CPU Set、Default CPU Set都还在。
- 当检测到Memory State已经成功初始化（根据Checkpoint restore），则检查这次启动时reserved cpu set是否都在Default CPU Set中，如果不是（比如kube/system reserved cpus增加了），则报错返回，因为这意味着reserved cpu set中有些cpus被Assigned到了某些Container中了，这可能会导致这些容器启动失败，此时需要用户自己手动的去修正Checkpoint文件。
- 检测reserved cpu set通过后，再检测Default CPU Set和Assigned CPU Set是否有交集，如果有交集，说明Checkpoint文件restore到Memory State的数据有错，报错返回。
- 最后检查这次启动时从cAdvisor中获取到的CPU Topology中的所有CPUs是否与Memory State（从Checkpoint中restore）中记录的所有CPUs（Default CPU Set + Assigned CPU Set）相同，如果不同，则报错返回。可能因为上次CPU Manager停止到这次启动这个时间内，Node上的可用CPUs发生变化。

```
pkg/kubelet/cm/cpumanager/policy_static.go:116

func (p *staticPolicy) validateState(s state.State) error {
	tmpAssignments := s.GetCPUAssignments()
	tmpDefaultCPUset := s.GetDefaultCPUSet()

	// Default cpuset cannot be empty when assignments exist
	if tmpDefaultCPUset.IsEmpty() {
		if len(tmpAssignments) != 0 {
			return fmt.Errorf("default cpuset cannot be empty")
		}
		// state is empty initialize
		allCPUs := p.topology.CPUDetails.CPUs()
		s.SetDefaultCPUSet(allCPUs)
		return nil
	}

	// State has already been initialized from file (is not empty)
	// 1. Check if the reserved cpuset is not part of default cpuset because:
	// - kube/system reserved have changed (increased) - may lead to some containers not being able to start
	// - user tampered with file
	if !p.reserved.Intersection(tmpDefaultCPUset).Equals(p.reserved) {
		return fmt.Errorf("not all reserved cpus: \"%s\" are present in defaultCpuSet: \"%s\"",
			p.reserved.String(), tmpDefaultCPUset.String())
	}

	// 2. Check if state for static policy is consistent
	for cID, cset := range tmpAssignments {
		// None of the cpu in DEFAULT cset should be in s.assignments
		if !tmpDefaultCPUset.Intersection(cset).IsEmpty() {
			return fmt.Errorf("container id: %s cpuset: \"%s\" overlaps with default cpuset \"%s\"",
				cID, cset.String(), tmpDefaultCPUset.String())
		}
	}

	// 3. It's possible that the set of available CPUs has changed since
	// the state was written. This can be due to for example
	// offlining a CPU when kubelet is not running. If this happens,
	// CPU manager will run into trouble when later it tries to
	// assign non-existent CPUs to containers. Validate that the
	// topology that was received during CPU manager startup matches with
	// the set of CPUs stored in the state.
	totalKnownCPUs := tmpDefaultCPUset.Clone()
	for _, cset := range tmpAssignments {
		totalKnownCPUs = totalKnownCPUs.Union(cset)
	}
	if !totalKnownCPUs.Equals(p.topology.CPUDetails.CPUs()) {
		return fmt.Errorf("current set of available CPUs \"%s\" doesn't match with CPUs in state \"%s\"",
			p.topology.CPUDetails.CPUs().String(), totalKnownCPUs.String())
	}

	return nil
}
```

## 思考

1. 某个CPU在Shared Pool中被非Guaranteed Pod Containers使用时，后来被CPU Manager分配给某个Static Policy Container,那么原来这个CPU上的任务会怎么样？立刻被调度到其他Shared Pool中的CPUs吗？

![img](https://oscimg.oschina.net/oscnet/30f9ccc4648a9a6f7a05d091bdc9767a049.jpg)

由于Static Policy Container Add的时候，除了为自己挑选最佳CPU Set外，还会把挑选的CPU Set从Shared Pool CPU Set中删除，因此上面这种情况下，原来的这个CPU上的任务会继续执行等cpu scheduler下次调度任务时，因为cpuset cgroups的生效，将导致他们看不到原来的那块CPU了。

1. Static Policy Container从头到尾都一定是绑定分配的CPUs吗？

从前面分析的工作流可知，当某Static Policy Container被分配了某些CPUs后，通过每10s（默认）一次的Reconcile将Memory State中分配情况更新到cpuset cgroups中，因此最坏会有10s时间这个Static Policy Container将和非Static Policy Container共享这个CPU。

1. CPU Manager的Checkpoint文件被破坏，与实际的CPU Assigned情况不一致，该如何修复？

通过对CPU Manager的分析，我们知道Reconcile并不能自己修复这个差异。可以通过以下方法修复：

方法1：重新生成Checkpoint文件：删除Checkpoint文件，并重启Kubelet，CPU Manager的Reconcile机制会遍历所有Containers，并重新为这些满足Static Policy条件的Containers分配CPUs，并更新到cpuset cgroups中。这可能会导致运行中的Container重新被分配到不同的CPU Set中而出现短时间的应用抖动。

方法2：Drain这个node，将Pod驱逐走，让Pod在其他正常Checkpoint的Node上调度，然后清空或者删除Checkpoint文件。这个方法也会对应用造成一点的影响，毕竟Pod需要在其他Node上recreate。

## CPU Manager的不足

- 基于当前cAdvisor对CPU Topology的Discover能力，目前CPU Manager在为Container挑选CPUs考虑cpu socket是否靠近某些PCI Bus。

![img](https://oscimg.oschina.net/oscnet/019d74f133d684bfcc1d9078c781bb49e04.jpg)

- CPU Manager还不支持对`isolcpus` Linux kernel boot parameter的兼容，CPU Manager需要（通过cAdvisor或者直接读）获取`isolcpus`配置的isolate CPUs，并在给Static Policy Contaienrs分配时排除这些isolate CPUs。
- 还不支持Dynamic分配，在Container运行过程中直接更改起cpuset cgroups。

## 总结

通过对Kubelet CPU Manager的深入分析，我们对CPU Manager的工作机制有了充分的理解，包括其Reconcile Loop、启动时的Validate Sate机制、Checkpoint的机制及其修复方法、CPU Manager当前不足等。