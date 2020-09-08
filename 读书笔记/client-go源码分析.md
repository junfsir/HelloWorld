### `client-go`代码结构

`Kubernetes`系统使用`client-go`作为Go语言的官方编程式交互客户端库，提供对`Kubernetes API Server`服务的交互访问。在`Kubernetes`的源码库中已经集成了`client-go`的源码，路径为`vender/k8s.io/client-go`，其代码结构及说明：

```shell
# tree vendor/k8s.io/client-go/ -L 1
vendor/k8s.io/client-go/
├── BUILD
├── code-of-conduct.md
├── CONTRIBUTING.md
├── deprecated
├── discovery  # 提供DiscoveryClient发现客户端
├── dynamic    # 提供DynamicClient动态客户端
├── examples
├── Godeps
├── go.mod
├── go.sum
├── informers  # 每种Kubernetes资源的Informer实现
├── INSTALL.md
├── kubernetes # 提供ClientSet客户端
├── kubernetes_test
├── LICENSE
├── listers    # 为每一个Kubernetes资源提供Lister功能，该功能对Get和List请求提供只读的缓存数据
├── metadata
├── OWNERS
├── pkg
├── plugin     # 提供OpenStack、GCP和Azure等云服务商授权插件
├── rest       # 提供RESTClient客户端，对Kubernetes API Server执行RESTful操作
├── restmapper
├── scale      # 提供ScaleClient客户端，用于扩容或缩容Deployment、ReplicaSet等资源对象
├── SECURITY_CONTACTS
├── testing
├── third_party
├── tools      # 提供常用工具，例如SharedInformer、Reflector、DealtFIFO及Indexers；提供Client查询和缓存机制，以减少向kube-apiserver发起的请求数等
├── transport  # 提供安全的TCP连接，支持Http Stream，某些操作需要在客户端和容器之间传输二进制流，例如exec、attach等操作，该功能由内部的spdy包提供支持
└── util       # 提供常用方法，例如WorkQueue工作队列、Certificate证书管理等
```

### `Client`客户端对象

`client-go`支持4种Client客户端对象与Kubernetes API Server交互的方式，如图所示：

[Client交互对象](../images/client-go/Client交互对象.png)

RESTClient是最基础的客户端，对HTTP Request进行了封装，实现了RESTful风格的API。ClientSet、DynamicSet、DIscoveryClient客户点都是基于RESTClient实现的。