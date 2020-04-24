在某些场景下，客户端需要直接访问`service`后端的`pod`，如`spring-cloud`注册，这时就应该向客户端暴露每个`pod`的`endpoints`，而不再是中间层`service`的`ClusterIP`，这类`service`资源称为`headless service`。

`Headless Service`对象没有`ClusterIP`，于是`kube-proxy`便无须处理此类请求，也就更没有了负载均衡或代理它的需要；在前端应用拥有自有的其他服务发现机制时，`Headless Service`即可省去定义`ClusterIP`的需求；至于如何为此类`Service`资源配置IP地址，则取决于它的`label selector`的定义；

- 具有`label selector`：`EndpointsController`会在API中为其创建`Endpoints`记录，并将`ClusterDNS`服务中的A记录直接解析到此`Service`后端的各`Pod`对象的`IP`地址上；
- 没有`label selector`：`EndpointsController`不会在API中为其创建`Endpoints`记录，`ClusterDNS`的配置分为两种情形，对`ExternalName`类型的服务创建`CNAME`记录，对其他三种类型来说，为那些与当前`Service`共享名称的所有`Endpoints`对象创建一条记录；

#### 创建`headless service`资源

配置`Service`资源配置清单时，只需要将`ClusterIP`字段的值设置为`None`即可将其定义为`Headless`类型；

```yaml
apiVersion: v1
kind: Service
metadata:
  name: spring-cloud-2-headless
spec:
  clusterIP: None
  ports:
  - name: spring-cloud-2-26001
    port: 26001
    protocol: TCP
    targetPort: 26001
  selector:
    app: spring-cloud-2
  sessionAffinity: None
  type: ClusterIP
```

根据`Headless Service`的工作特性可知，它记录于`ClusterDNS`的A记录的相关解析结果是后端`Pod`资源的`IP`地址，这就意味着客户端通过此`Service`资源的名称发现的是各`Pod`资源。