### `SharedInformer`&`ListWatcher`

`Controller`通过`SharedInformer`监控`apiserver`中资源对象的状态变化，以此来缓解`apiserver`的压力，并提高效率；

`Controller`通过`ListWatcher`给`apiserver`发送一个查询后等待，当监控的资源对象有变化时，`apiserver`通过分块的`http`响应通知`Controller`；控制器看到`chunked`响应，会认为响应数据还没有发送完成，所以会持续等待；

### `PLEG`

`Pod Lifecycle Event Generator`是`kubelet`中的一个模块，通过匹配`Pod`级别的事件来调整容器的运行时状态，并将调整的结果写入缓存，使`Pod`的缓存保持最新；

`Pod`的生命周期事件是在`Pod`层面上对底层容器状态变更的抽象，使其与底层的容器运行时无关，这样就可以让 `Kubelet` 不受底层容器运行时的影响；

[参考](https://fuckcloudnative.io/posts/understanding-the-pleg-is-not-healthy/)