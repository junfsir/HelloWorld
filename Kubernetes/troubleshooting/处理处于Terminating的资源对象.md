在集群的日常维护中，会遇到出于处于 `Terminating` 状态的资源，以处理处于 `Terminating` 的 `namespaces` 为例，删除`finalizers`对应的值即可：

```shell
# kubectl edit pvc xxx

  finalizers:
  - kubernetes.io/pvc-protection # 删除此行
```





[详解 Kubernetes 垃圾收集器的实现原理]( https://draveness.me/kubernetes-garbage-collector )

[垃圾收集]( https://kubernetes.io/zh/docs/concepts/workloads/controllers/garbage-collection/ )

