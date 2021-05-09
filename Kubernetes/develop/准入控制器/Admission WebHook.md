Kubernetes 提供了需要扩展其内置功能的方法，最常用的可能是自定义资源类型和自定义控制器了，除此之外，Kubernetes 还有一些其他非常有趣的功能，比如 `admission webhooks` 就可以用于扩展 API，用于修改某些 Kubernetes 资源的基本行为。

准入控制器是在**对象持久化之前**用于对 Kubernetes API Server 的请求进行拦截的代码段，在请求经过**身份验证**和**授权之后**放行通过。准入控制器可能正在 `validating`、`mutating` 或者都在执行，`Mutating` 控制器可以修改他们处理的资源对象，`Validating` 控制器不会，如果任何一个阶段中的任何控制器拒绝了请求，则会立即拒绝整个请求，并将错误返回给最终的用户。

这意味着有一些特殊的控制器可以拦截 Kubernetes API 请求，并根据自定义的逻辑修改或者拒绝它们。Kubernetes 有自己实现的一个控制器列表：https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#what-does-each-admission-controller-do，当然你也可以编写自己的控制器，虽然这些控制器听起来功能比较强大，但是这些控制器需要被编译进 kube-apiserver，并且只能在 apiserver 启动时启动。

由于上面的控制器的限制，我们就需要用到**动态**的概念了，而不是和 apiserver 耦合在一起，`Admission webhooks` 就通过一种动态配置方法解决了这个限制问题。

## admission webhook 是什么?

在 Kubernetes apiserver 中包含两个特殊的准入控制器：`MutatingAdmissionWebhook` 和`ValidatingAdmissionWebhook`，这两个控制器将发送准入请求到外部的 HTTP 回调服务并接收一个准入响应。如果启用了这两个准入控制器，Kubernetes 管理员可以在集群中创建和配置一个 admission webhook。

![](../../../images/k8s-dev/k8s-api-request-lifecycle.png)

整体的步骤如下所示：

- 检查集群中是否启用了 admission webhook 控制器，并根据需要进行配置。
- 编写处理准入请求的 HTTP 回调，回调可以是一个部署在集群中的简单 HTTP 服务，甚至也可以是一个 `serverless` 函数，例如 https://github.com/kelseyhightower/denyenv-validating-admission-webhook 这个项目。
- 通过 `MutatingWebhookConfiguration` 和 `ValidatingWebhookConfiguration` 资源配置 admission webhook。

这两种类型的 admission webhook 之间的区别是非常明显的：`validating webhooks` 可以拒绝请求，但是它们却不能修改准入请求中获取的对象，而 `mutating webhooks` 可以在返回准入响应之前通过创建补丁来修改对象，如果 webhook 拒绝了一个请求，则会向最终用户返回错误。

现在非常火热的 Service Mesh 应用 `istio` 就是通过 mutating webhooks 来自动将 `Envoy` 这个 sidecar 容器注入到 Pod 中去的：https://istio.io/docs/setup/kubernetes/sidecar-injection/。

## 创建配置一个 Admission Webhook

上面我们介绍了 Admission Webhook 的理论知识，接下来我们在一个真实的 Kubernetes 集群中来实际测试使用下，我们将创建一个 webhook 的 webserver，将其部署到集群中，然后创建 webhook 配置查看是否生效。

首先确保在 apiserver 中启用了 `MutatingAdmissionWebhook` 和 `ValidatingAdmissionWebhook` 这两个控制器，由于我这里集群使用的是 kubeadm 搭建的，可以通过查看 apiserver Pod 的配置：

```bash
$ kubectl get pods kube-apiserver-ydzs-master -n kube-system -o yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    component: kube-apiserver
    tier: control-plane
  name: kube-apiserver-ydzs-master
  namespace: kube-system
......
spec:
  containers:
  - command:
    - kube-apiserver
    - --advertise-address=10.151.30.11
    - --allow-privileged=true
    - --authorization-mode=Node,RBAC
    - --client-ca-file=/etc/kubernetes/pki/ca.crt
    - --enable-admission-plugins=NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook
......
```

上面的 `enable-admission-plugins` 参数中带上了 `MutatingAdmissionWebhook` 和`ValidatingAdmissionWebhook` 两个准入控制插件，如果没有的（当前 v1.19.x 版本是默认开启的），需要添加上这两个参数，然后重启 apiserver。

然后通过运行下面的命令检查集群中是否启用了准入注册 API：

```bash
$ kubectl api-versions |grep admission
admissionregistration.k8s.io/v1
admissionregistration.k8s.io/v1beta1
```

