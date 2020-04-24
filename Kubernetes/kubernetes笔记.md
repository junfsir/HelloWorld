### `SharedInformer`&`ListWatcher`

`Controller`通过`SharedInformer`监控`apiserver`中资源对象的状态变化，以此来缓解`apiserver`的压力，并提高效率；

`Controller`通过`ListWatcher`给`apiserver`发送一个查询后等待，当监控的资源对象有变化时，`apiserver`通过分块的`http`响应通知`Controller`；控制器看到`chunked`响应，会认为响应数据还没有发送完成，所以会持续等待；