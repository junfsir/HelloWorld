# [使用 client-go 对 Kubernetes 进行自定义开发及源码分析](https://cloud.tencent.com/developer/article/1433227)

## 1、client-go 介绍

>  client-go 是一种能够与 Kubernetes 集群通信的客户端，通过它可以对 Kubernetes 集群中各资源类型进行 CRUD 操作，它有三大 client 类，分别为：`Clientset`、`DynamicClient`、`RESTClient`。通过它，我们可以很方便的对 Kubernetes 集群 API 进行自定义开发，来满足个性化需求。 

## 2、client-go 安装

[client-go](https://github.com/kubernetes/client-go) 安装很简单，前提是本机已经安装并配置好了 Go 环境，安装之前，我们需要先查看下其版本针对 k8s 版本 [兼容性列表](https://github.com/kubernetes/client-go#compatibility-matrix)，针对自己本机安装的 k8s 版本选择对应的 client-go 版本，当然也可以默认选择最新版本，来兼容所有。

client-go 安装方式有多种，比如 `go get`、`Godep`、`Glide` 方式。如果我们本地没有安装 `Godep` 和 `Glide` 依赖管理工具的话，可以使用最简单的 `go get` 下载安装。

```shell
$ go get k8s.io/client-go/...
```

执行该命令将会自动将 `k8s.io/client-go` 下载到本机 `$GOPATH`，默认下载的源码中只包含了大部分依赖，并将其放在 `k8s.io/client-go/vendor` 路径，但是如果想成功运行的话，还需要另外两个依赖库 `k8s.io/client-go/vendor` 和 `glog`，所以还需要接着执行如下命令。

```shell
$ go get -u k8s.io/apimachinery/...
```

说明一下，为什么要使用 `-u` 参数来拉取最新的该依赖库呢？那是因为最新的 client-go 库只能保证跟最新的 `apimachinery` 库一起运行。其他几种安装方式，可以参考 [这里](https://github.com/kubernetes/client-go/blob/master/INSTALL.md) 来执行，这里就不在演示了。

## 3、在 k8s 集群外运行客户端操作资源示例

好了，本机 client-go 已经安装完毕，而且本机 Minikube 运行的 k8s 集群也已经运行起来了，接下来，我们简单演示下如果通过 client-go 来在 k8s 集群外运行客户端来操作各资源类型。

新建 `main.go` 文件如下：

```go
package main

import (
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
)

func main() {
	// 配置 k8s 集群外 kubeconfig 配置文件，默认位置 $HOME/.kube/config
	var kubeconfig *string
	if home := homeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	//在 kubeconfig 中使用当前上下文环境，config 获取支持 url 和 path 方式
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err.Error())
	}

	// 根据指定的 config 创建一个新的 clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}
	for {
		// 通过实现 clientset 的 CoreV1Interface 接口列表中的 PodsGetter 接口方法 Pods(namespace string) 返回 PodInterface
		// PodInterface 接口拥有操作 Pod 资源的方法，例如 Create、Update、Get、List 等方法
		// 注意：Pods() 方法中 namespace 不指定则获取 Cluster 所有 Pod 列表
		pods, err := clientset.CoreV1().Pods("").List(metav1.ListOptions{})
		if err != nil {
			panic(err.Error())
		}
		fmt.Printf("There are %d pods in the k8s cluster\n", len(pods.Items))

		// 获取指定 namespace 中的 Pod 列表信息
		namespace := "kubeless"
		pods, err = clientset.CoreV1().Pods(namespace).List(metav1.ListOptions{})
		if err != nil {
			panic(err)
		}
		fmt.Printf("\nThere are %d pods in namespaces %s\n", len(pods.Items), namespace)
		for _, pod := range pods.Items {
			fmt.Printf("Name: %s, Status: %s, CreateTime: %s\n", pod.ObjectMeta.Name, pod.Status.Phase, pod.ObjectMeta.CreationTimestamp)
		}

		// 获取指定 namespaces 和 podName 的详细信息，使用 error handle 方式处理错误信息
		namespace = "kubeless"
		podName := "get-java-5ff45cd65d-2frkx"
		pod, err := clientset.CoreV1().Pods(namespace).Get(podName, metav1.GetOptions{})
		if errors.IsNotFound(err) {
			fmt.Printf("Pod %s in namespace %s not found\n", podName, namespace)
		} else if statusError, isStatus := err.(*errors.StatusError); isStatus {
			fmt.Printf("Error getting pod %s in namespace %s: %v\n",
				podName, namespace, statusError.ErrStatus.Message)
		} else if err != nil {
			panic(err.Error())
		} else {
			fmt.Printf("\nFound pod %s in namespace %s\n", podName, namespace)
			maps := map[string]interface{}{
				"Name":        pod.ObjectMeta.Name,
				"Namespaces":  pod.ObjectMeta.Namespace,
				"NodeName":    pod.Spec.NodeName,
				"Annotations": pod.ObjectMeta.Annotations,
				"Labels":      pod.ObjectMeta.Labels,
				"SelfLink":    pod.ObjectMeta.SelfLink,
				"Uid":         pod.ObjectMeta.UID,
				"Status":      pod.Status.Phase,
				"IP":          pod.Status.PodIP,
				"Image":       pod.Spec.Containers[0].Image,
			}
			prettyPrint(maps)
		}

		time.Sleep(10 * time.Second)
	}
}

func prettyPrint(maps map[string]interface{}) {
	lens := 0
	for k, _ := range maps {
		if lens <= len(k) {
			lens = len(k)
		}
	}
	for key, values := range maps {
		spaces := lens - len(key)
		v := ""
		for i := 0; i < spaces; i++ {
			v += " "
		}
		fmt.Printf("%s: %s%v\n", key, v, values)
	}
}

func homeDir() string {
	if h := os.Getenv("HOME"); h != "" {
		return h
	}
	return os.Getenv("USERPROFILE") // windows
}
```

简单说明一下，该示例主要演示如何在 k8s 集群外操作 Pod 资源类型，包括获取集群所有 Pod 列表数量，获取指定 Namespace 中的 Pod 列表信息，获取指定 Namespace 和 Pod Name 的详细信息。代码里面关键步骤简单添加了一些注释，详细的代码调用过程，下边 client-go 源码分析里面会讲到。这里要提一下的是，这种方式获取 k8s 集群配置的方式为通过读取 `kubeconfig` 配置文件，默认位置 `$HOME/.kube/config`，来跟 k8s 建立连接，进而来操作其各个资源类型。运行一下，看下效果如何。

```shell
$ go run main.go
There are 30 pods in the k8s cluster

There are 3 pods in namespaces kubeless
Name: get-java-5ff45cd65d-2frkx, Status: Running, CreateTime: 2018-08-23 10:36:37 +0800 CST
Name: kubeless-controller-manager-5d7894857d-h4hr9, Status: Running, CreateTime: 2018-08-22 17:01:59 +0800 CST
Name: ui-5b87d84d96-vkmz7, Status: Running, CreateTime: 2018-08-23 15:13:25 +0800 CST

Found pod get-java-5ff45cd65d-2frkx in namespace kubeless
Status:      Running
Image:       kubeless/java@sha256:debf9502545f4c0e955eb60fabb45748c5d98ed9365c4a508c07f38fc7fefaac
Namespaces:  kubeless
NodeName:    minikube
Uid:         5bd5cfce-a67d-11e8-862b-080027c7f5ce
SelfLink:    /api/v1/namespaces/kubeless/pods/get-java-5ff45cd65d-2frkx
IP:          172.17.0.5
Name:        get-java-5ff45cd65d-2frkx
Annotations: map[prometheus.io/path:/metrics prometheus.io/port:8080 prometheus.io/scrape:true]
Labels:      map[created-by:kubeless function:get-java pod-template-hash:1990178218]
```

可以成功获取到资源信息，我们可以通过 `kubectl` 客户端工具来验证一下吧！

```shell
# 获取 kubeless 命令空间下所有 pod
$ kubectl get pods -n kubeless
NAME                                           READY     STATUS    RESTARTS   AGE
get-java-5ff45cd65d-2frkx                      1/1       Running   2          98d
kubeless-controller-manager-5d7894857d-h4hr9   3/3       Running   18         98d
ui-5b87d84d96-vkmz7                            2/2       Running   5          97d

# 获取 kubeless 命令空间下名称为 get-java-5ff45cd65d-2frkx 的 Pod 的信息
$ kubectl get pod/get-java-5ff45cd65d-2frkx -o yaml -n kubeless
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/path: /metrics
    prometheus.io/port: "8080"
    prometheus.io/scrape: "true"
  creationTimestamp: 2018-08-23T02:36:37Z
  generateName: get-java-5ff45cd65d-
  labels:
    created-by: kubeless
    function: get-java
    pod-template-hash: "1990178218"
  name: get-java-5ff45cd65d-2frkx
  namespace: kubeless
  ownerReferences:
  - apiVersion: extensions/v1beta1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicaSet
    name: get-java-5ff45cd65d
    uid: 5bd1e6c3-a67d-11e8-862b-080027c7f5ce
  resourceVersion: "1284918"
  selfLink: /api/v1/namespaces/kubeless/pods/get-java-5ff45cd65d-2frkx
  uid: 5bd5cfce-a67d-11e8-862b-080027c7f5ce
spec:
  containers:
  - env:
    - name: FUNC_HANDLER
      value: foo
      ......
```

可以看到，两种方式获取的信息是一致的。

## 4、在 k8s 集群内运行客户端操作资源示例

接下来，我们演示下如何在 k8s 集群内运行客户端操作资源类型。既然是在 k8s 集群内运行，那么就需要将编写的代码放到镜像内，然后在 k8s 集群内以 Pod 方式运行该镜像容器，来验证一下了。新建 `main.go` 代码如下：

```go
package main

import (
	"fmt"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

func main() {
	// 通过集群内部配置创建 k8s 配置信息，通过 KUBERNETES_SERVICE_HOST 和 KUBERNETES_SERVICE_PORT 环境变量方式获取
	// 若集群使用 TLS 认证方式，则默认读取集群内部 tokenFile 和 CAFile
	// tokenFile  = "/var/run/secrets/kubernetes.io/serviceaccount/token"
	// rootCAFile = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}

	// 根据指定的 config 创建一个新的 clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}
	for {
		// 通过实现 clientset 的 CoreV1Interface 接口列表中的 PodsGetter 接口方法 Pods(namespace string) 返回 PodInterface
		// PodInterface 接口拥有操作 Pod 资源的方法，例如 Create、Update、Get、List 等方法
		// 注意：Pods() 方法中 namespace 不指定则获取 Cluster 所有 Pod 列表
		pods, err := clientset.CoreV1().Pods("").List(metav1.ListOptions{})
		if err != nil {
			panic(err.Error())
		}
		fmt.Printf("There are %d pods in the k8s cluster\n", len(pods.Items))

		// 获取指定 namespace 中的 Pod 列表信息
		namespce := "kubeless"
		pods, err = clientset.CoreV1().Pods(namespce).List(metav1.ListOptions{})
		if err != nil {
			panic(err)
		}
		fmt.Printf("\nThere are %d pods in namespaces %s\n", len(pods.Items), namespce)
		for _, pod := range pods.Items {
			fmt.Printf("Name: %s, Status: %s, CreateTime: %s\n", pod.ObjectMeta.Name, pod.Status.Phase, pod.ObjectMeta.CreationTimestamp)
		}

		// 获取所有的 Namespaces 列表信息
		ns, err := clientset.CoreV1().Namespaces().List(metav1.ListOptions{})
		if err != nil {
			panic(err)
		}
		nss := ns.Items
		fmt.Printf("\nThere are %d namespaces in cluster\n", len(nss))
		for _, ns := range nss {
			fmt.Printf("Name: %s, Status: %s, CreateTime: %s\n", ns.ObjectMeta.Name, ns.Status.Phase, ns.CreationTimestamp)
		}

		time.Sleep(10 * time.Second)
	}
}
```

简单说下，该示例主要演示如何在 k8s 集群内操作 Pod 和 Namespaces 资源类型，包括获取集群所有 Pod 列表数量，获取指定 Namespace 中的 Pod 列表信息，获取集群内所有 Namespace 列表信息。这里，该方式获取 k8s 集群配置的方式跟上边方式不同，它通过集群内部创建的 k8s 配置信息，通过 `KUBERNETES_SERVICE_HOST` 和 `KUBERNETES_SERVICE_PORT` 环境变量方式获取，来跟 k8s 建立连接，进而来操作其各个资源类型。如果 k8s 开启了 TLS 认证方式，那么默认读取集群内部指定位置的 `tokenFile` 和 `CAFile`。

那么，编译一下，看下是否通过。

```shell
$ cd <code_path>
$ GOOS=linux go build -o ./app .
```

接下来，在同级目录创建一个 `Dockerfile` 文件如下:

```yaml
FROM debian
COPY ./app /app
ENTRYPOINT /app
```

说明一下，这里 `app` 为上边代码编译后可以直接运行的二进制文件，将该文件添加到镜像内，最后运行该文件即可。接下来，我们需要 Build 镜像并上传到镜像仓库，来提供拉取。注意：这里因为我们本地使用 Minikube 运行 k8s 集群，那么可以不需要上传镜像到仓库，直接构建到本地，然后在启动该镜像时，指定拉取策略为 `--image-pull-policy=Never`，即可从本地直接使用镜像。

```shell
$ eval $(minikube docker-env)
$ docker build -t client-go/in-cluster:1.0 .
Sending build context to Docker daemon  32.76MB
Step 1/3 : FROM debian
 ---> be2868bebaba
Step 2/3 : COPY ./app /app
 ---> 0f424ab04f5c
Step 3/3 : ENTRYPOINT /app
 ---> Running in ce12b6e4d7fc
Removing intermediate container ce12b6e4d7fc
 ---> c6ce75b50123
Successfully built c6ce75b50123
Successfully tagged client-go/in-cluster:1.0

$ docker images|head -1;docker images|grep client-go
REPOSITORY                TAG         IMAGE ID            CREATED              SIZE
client-go/in-cluster      1.0         c6ce75b50123        About a minute ago   133MB
```

因为本机 k8s 默认开启了 RBAC 认证的，所以需要创建一个 `clusterrolebinding` 来赋予  default 账户 view 权限。

```shell
$ kubectl create clusterrolebinding default-view --clusterrole=view --serviceaccount=default:default
clusterrolebinding.rbac.authorization.k8s.io "default-view" created
```

最后，在 Pod 中运行该镜像即可，这里可以使用 yaml 方式来创建，简单些直接使用 `kubectl run` 命令来创建。

```shell
$ kubectl run --rm -i client-go-in-cluster-demo --image=client-go/in-cluster:1.0 --image-pull-policy=Never
If you don't see a command prompt, try pressing enter.
There are 30 pods in the k8s cluster

There are 3 pods in namespaces kubeless
Name: get-java-5ff45cd65d-2frkx, Status: Running, CreateTime: 2018-08-23 02:36:37 +0000 UTC
Name: kubeless-controller-manager-5d7894857d-h4hr9, Status: Running, CreateTime: 2018-08-22 09:01:59 +0000 UTC
Name: ui-5b87d84d96-vkmz7, Status: Running, CreateTime: 2018-08-23 07:13:25 +0000 UTC

There are 8 namespaces in cluster
Name: default, Status: Active, CreateTime: 2018-08-07 09:17:15 +0000 UTC
Name: fission, Status: Active, CreateTime: 2018-09-06 08:19:32 +0000 UTC
Name: fission-builder, Status: Active, CreateTime: 2018-09-06 09:21:20 +0000 UTC
Name: fission-function, Status: Active, CreateTime: 2018-09-06 09:21:20 +0000 UTC
Name: kube-public, Status: Active, CreateTime: 2018-08-07 09:17:19 +0000 UTC
Name: kube-system, Status: Active, CreateTime: 2018-08-07 09:17:15 +0000 UTC
Name: kubeless, Status: Active, CreateTime: 2018-08-22 09:01:27 +0000 UTC
Name: monitoring, Status: Active, CreateTime: 2018-08-09 02:43:55 +0000 UTC
```

运行正常，简单验证一下吧！

```shell
$ kubectl get pods -n kubeless
NAME                                           READY     STATUS    RESTARTS   AGE
get-java-5ff45cd65d-2frkx                      1/1       Running   2          98d
kubeless-controller-manager-5d7894857d-h4hr9   3/3       Running   18         98d
ui-5b87d84d96-vkmz7                            2/2       Running   5          98d

$ kubectl get namespaces
NAME               STATUS    AGE
default            Active    113d
fission            Active    84d
fission-builder    Active    83d
fission-function   Active    83d
kube-public        Active    113d
kube-system        Active    113d
kubeless           Active    98d
monitoring         Active    112d
```

## 5、k8s 各资源对象 CRUD 操作示例

上边演示了，在 k8s 集群内外运行客户端操作资源类型，但是仅仅是 Read 相关读取操作，接下来简单演示下如何进行 Create、Update、Delete 操作。创建 `main.go` 文件如下：

```go
package main

import (
	"flag"
	"fmt"
	apiv1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/homedir"
	"path/filepath"
)

func main() {
	// 配置 k8s 集群外 kubeconfig 配置文件，默认位置 $HOME/.kube/config
	var kubeconfig *string
	if home := homedir.HomeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()

	//在 kubeconfig 中使用当前上下文环境，config 获取支持 url 和 path 方式
	config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
	if err != nil {
		panic(err)
	}

	// 根据指定的 config 创建一个新的 clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err)
	}

	// 通过实现 clientset 的 CoreV1Interface 接口列表中的 NamespacesGetter 接口方法 Namespaces 返回 NamespaceInterface
	// NamespaceInterface 接口拥有操作 Namespace 资源的方法，例如 Create、Update、Get、List 等方法
	name := "client-go-test"
	namespacesClient := clientset.CoreV1().Namespaces()
	namespace := &apiv1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: name,
		},
		Status: apiv1.NamespaceStatus{
			Phase: apiv1.NamespaceActive,
		},
	}

	// 创建一个新的 Namespaces
	fmt.Println("Creating Namespaces...")
	result, err := namespacesClient.Create(namespace)
	if err != nil {
		panic(err)
	}
	fmt.Printf("Created Namespaces %s on %s\n", result.ObjectMeta.Name, result.ObjectMeta.CreationTimestamp)

	// 获取指定名称的 Namespaces 信息
	fmt.Println("Getting Namespaces...")
	result, err = namespacesClient.Get(name, metav1.GetOptions{})
	if err != nil {
		panic(err)
	}
	fmt.Printf("Name: %s, Status: %s, selfLink: %s, uid: %s\n",
		result.ObjectMeta.Name, result.Status.Phase, result.ObjectMeta.SelfLink, result.ObjectMeta.UID)

	// 删除指定名称的 Namespaces 信息
	fmt.Println("Deleting Namespaces...")
	deletePolicy := metav1.DeletePropagationForeground
	if err := namespacesClient.Delete(name, &metav1.DeleteOptions{
		PropagationPolicy: &deletePolicy,
	}); err != nil {
		panic(err)
	}
	fmt.Printf("Deleted Namespaces %s\n", name)
}
```

该示例主要演示如何在 k8s 集群内操作 Namespace 资源类型，包括创建一个新的 Namespace、获取该 Namespace 的详细信息，删除该 Namespace。采用 k8s 集群外运行客户端操作资源方式来操作。运行结果如下：

```shell
$ go run main.go 
Creating Namespaces...
Created Namespaces client-go-test on 2018-11-29 17:38:25 +0800 CST
Getting Namespaces...
Name: client-go-test, Status: Active, selfLink: /api/v1/namespaces/client-go-test, uid: 84c55ca3-f3ba-11e8-9302-080027c7f5ce
Deleting Namespaces...
Deleted Namespaces client-go-test
```

这里就不在验证了，因为我们创建完了后又删除了，如果想验证，可以按照官方的方法，键盘输入来继续执行，这样就可以在每一步等待输入的时候，去做验证了。这里只是简单的拿 Namespace 演示一下，使用 client-go 可以操作 k8s 各种资源类型，方法都大同小异，这里就不在演示了。

## 6、client-go 源码分析

最后，我们以 [4、在 k8s 集群外运行客户端操作资源示例](https://mp.csdn.net/mdeditor#4_k8s__36) 中的代码为例，简单分析一下 client-go 的底层执行过程，这里涉及到几个关键的对象：`kubeconfig`、`restclient.Config`、`Clientset`、`CoreV1Interface`、`Pod` 等。

### 6.1、kubeconfig

```go
	var kubeconfig *string
	if home := homeDir(); home != "" {
		kubeconfig = flag.String("kubeconfig", filepath.Join(home, ".kube", "config"), "(optional) absolute path to the kubeconfig file")
	} else {
		kubeconfig = flag.String("kubeconfig", "", "absolute path to the kubeconfig file")
	}
	flag.Parse()
```

使用 client-go 在 k8s 集群外操作资源，首先需要通过获取 kubeconfig 配置文件，来建立连接。默认路径为 `$HOME/.kube/config`。config 文件包含当前 kubernetes 集群配置信息，大致如下：

```yaml
$ cat $HOME/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: <token>
    server: https://127.0.0.1:8443
  name: 127-0-0-1:8443
contexts:
- context:
    cluster: 127-0-0-1:8443
    namespace: default
    user: system:admin/127-0-0-1:8443
  name: default/127-0-0-1:8443/system:admin
current-context: minikube
kind: Config
preferences: {}
users:
- name: system:admin/127-0-0-1:8443
  user:
    client-certificate-data: <token>
    client-key-data: <token>
```

### 6.2、restclient.Config

```go
config, err := clientcmd.BuildConfigFromFlags("", *kubeconfig)
```

接着在 kubeconfig 中使用当前上下文环境，config 获取支持 url 和 path 方式，通过 `BuildConfigFromFlags()` 函数获取 `restclient.Config` 对象，用来下边根据该 config 对象创建 client 集合。

```go
func BuildConfigFromFlags(masterUrl, kubeconfigPath string) (*restclient.Config, error) {
	if kubeconfigPath == "" && masterUrl == "" {
		klog.Warningf("Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work.")
		kubeconfig, err := restclient.InClusterConfig()
		if err == nil {
			return kubeconfig, nil
		}
		klog.Warning("error creating inClusterConfig, falling back to default config: ", err)
	}
	return NewNonInteractiveDeferredLoadingClientConfig(
		&ClientConfigLoadingRules{ExplicitPath: kubeconfigPath},
		&ConfigOverrides{ClusterInfo: clientcmdapi.Cluster{Server: masterUrl}}).ClientConfig()
}
```

### 6.3、Clientset

```go
clientset, err := kubernetes.NewForConfig(config)
```

接着根据获取的 config 来创建一个 clientset 对象。通过调用 `NewForConfig` 函数创建 clientset 对象。`NewForConfig` 函数具体实现就是初始化 clientset 中的每个 client，基本涵盖了 k8s 内各种类型。

```go
// NewForConfig creates a new Clientset for the given config.
func NewForConfig(c *rest.Config) (*Clientset, error) {
	configShallowCopy := *c
	if configShallowCopy.RateLimiter == nil && configShallowCopy.QPS > 0 {
		configShallowCopy.RateLimiter = flowcontrol.NewTokenBucketRateLimiter(configShallowCopy.QPS, configShallowCopy.Burst)
	}
	var cs Clientset
	var err error
	cs.admissionregistrationV1alpha1, err = admissionregistrationv1alpha1.NewForConfig(&configShallowCopy)
	if err != nil {
		return nil, err
	}
	......	
	cs.appsV1, err = appsv1.NewForConfig(&configShallowCopy)
	if err != nil {
		return nil, err
	}
	......
	cs.coreV1, err = corev1.NewForConfig(&configShallowCopy)
	if err != nil {
		return nil, err
	}
	......
	return &cs, nil
}
```

clientset 结构体定义如下：

```go
type Clientset struct {
	*discovery.DiscoveryClient
	admissionregistrationV1alpha1 *admissionregistrationv1alpha1.AdmissionregistrationV1alpha1Client
	admissionregistrationV1beta1  *admissionregistrationv1beta1.AdmissionregistrationV1beta1Client
	appsV1beta1                   *appsv1beta1.AppsV1beta1Client
	appsV1beta2                   *appsv1beta2.AppsV1beta2Client
	appsV1                        *appsv1.AppsV1Client
	auditregistrationV1alpha1     *auditregistrationv1alpha1.AuditregistrationV1alpha1Client
	authenticationV1              *authenticationv1.AuthenticationV1Client
	authenticationV1beta1         *authenticationv1beta1.AuthenticationV1beta1Client
	authorizationV1               *authorizationv1.AuthorizationV1Client
	authorizationV1beta1          *authorizationv1beta1.AuthorizationV1beta1Client
	autoscalingV1                 *autoscalingv1.AutoscalingV1Client
	autoscalingV2beta1            *autoscalingv2beta1.AutoscalingV2beta1Client
	autoscalingV2beta2            *autoscalingv2beta2.AutoscalingV2beta2Client
	batchV1                       *batchv1.BatchV1Client
	batchV1beta1                  *batchv1beta1.BatchV1beta1Client
	batchV2alpha1                 *batchv2alpha1.BatchV2alpha1Client
	certificatesV1beta1           *certificatesv1beta1.CertificatesV1beta1Client
	coordinationV1beta1           *coordinationv1beta1.CoordinationV1beta1Client
	coreV1                        *corev1.CoreV1Client
	eventsV1beta1                 *eventsv1beta1.EventsV1beta1Client
	extensionsV1beta1             *extensionsv1beta1.ExtensionsV1beta1Client
	networkingV1                  *networkingv1.NetworkingV1Client
	policyV1beta1                 *policyv1beta1.PolicyV1beta1Client
	rbacV1                        *rbacv1.RbacV1Client
	rbacV1beta1                   *rbacv1beta1.RbacV1beta1Client
	rbacV1alpha1                  *rbacv1alpha1.RbacV1alpha1Client
	schedulingV1alpha1            *schedulingv1alpha1.SchedulingV1alpha1Client
	schedulingV1beta1             *schedulingv1beta1.SchedulingV1beta1Client
	settingsV1alpha1              *settingsv1alpha1.SettingsV1alpha1Client
	storageV1beta1                *storagev1beta1.StorageV1beta1Client
	storageV1                     *storagev1.StorageV1Client
	storageV1alpha1               *storagev1alpha1.StorageV1alpha1Client
}
```

### 6.4、CoreV1Interface

```go
pods, err := clientset.CoreV1().Pods("").List(metav1.ListOptions{})
```

接着通过实现 clientset 的 `CoreV1Interface` 接口列表中的 `PodsGetter` 接口方法 `Pods(namespace string)` 返回 `PodInterface`。从上边可以看到 clientset 包含很多种 client，我们来使用 `CoreV1Client` 来实现 `CoreV1Interface` 接口中各资源类型的 Getter 接口。因为这里演示的是操作 Pod，那么就需要实现 `PodsGette` 接口方法。

`CoreV1Interface` 接口定义如下：

```go
type CoreV1Interface interface {
	RESTClient() rest.Interface
	ComponentStatusesGetter
	ConfigMapsGetter
	EndpointsGetter
	EventsGetter
	LimitRangesGetter
	NamespacesGetter
	NodesGetter
	PersistentVolumesGetter
	PersistentVolumeClaimsGetter
	PodsGetter
	PodTemplatesGetter
	ReplicationControllersGetter
	ResourceQuotasGetter
	SecretsGetter
	ServicesGetter
	ServiceAccountsGetter
}
```

`PodsGetter` 及 `PodInterface` 接口定义如下：

```go
type PodsGetter interface {
	Pods(namespace string) PodInterface
}

// PodInterface has methods to work with Pod resources.
type PodInterface interface {
	Create(*v1.Pod) (*v1.Pod, error)
	Update(*v1.Pod) (*v1.Pod, error)
	UpdateStatus(*v1.Pod) (*v1.Pod, error)
	Delete(name string, options *metav1.DeleteOptions) error
	DeleteCollection(options *metav1.DeleteOptions, listOptions metav1.ListOptions) error
	Get(name string, options metav1.GetOptions) (*v1.Pod, error)
	List(opts metav1.ListOptions) (*v1.PodList, error)
	Watch(opts metav1.ListOptions) (watch.Interface, error)
	Patch(name string, pt types.PatchType, data []byte, subresources ...string) (result *v1.Pod, err error)
	PodExpansion
}
```

从 `PodsInterface` 接口定义列表可以看到，里面包含了 `CRUD` 各种操作，通过这些方法，就可以操作 Pod 资源对象了。例如，上边我们调用了 `List(opts metav1.ListOptions)` 方法，返回 PodList 对象，那么看下 PodList 结构体如何定义的。

```go
// PodList is a list of Pods.
type PodList struct {
	metav1.TypeMeta `json:",inline"`
	// Standard list metadata.
	metav1.ListMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`
	// List of pods.
	Items []Pod `json:"items" protobuf:"bytes,2,rep,name=items"`
}
```

最后，我们就可以通过简单的执行 `len(pods.Items)` 方法获取集群内所有 Pod 的数量了。

### 6.5、Pod

```go
	// 获取指定 namespaces 和 podName 的详细信息，使用 error handle 方式处理错误信息
	namespace = "kubeless"
	podName := "get-java-5ff45cd65d-2frkx"
	pod, err := clientset.CoreV1().Pods(namespace).Get(podName, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		fmt.Printf("Pod %s in namespace %s not found\n", podName, namespace)
	} else if statusError, isStatus := err.(*errors.StatusError); isStatus {
		fmt.Printf("Error getting pod %s in namespace %s: %v\n",
			podName, namespace, statusError.ErrStatus.Message)
	} else if err != nil {
		panic(err.Error())
	} else {
		fmt.Printf("\nFound pod %s in namespace %s\n", podName, namespace)
		maps := map[string]interface{}{
			"Name":        pod.ObjectMeta.Name,
			"Namespaces":  pod.ObjectMeta.Namespace,
			"NodeName":    pod.Spec.NodeName,
			"Annotations": pod.ObjectMeta.Annotations,
			"Labels":      pod.ObjectMeta.Labels,
			"SelfLink":    pod.ObjectMeta.SelfLink,
			"Uid":         pod.ObjectMeta.UID,
			"Status":      pod.Status.Phase,
			"IP":          pod.Status.PodIP,
			"Image":       pod.Spec.Containers[0].Image,
		}
		prettyPrint(maps)
	}
```

第三个示例是获取指定 Namespace 中指定名称的 Pod 列表信息，操作方法跟上述一致，只是最后调用了 `Get(name string, options metav1.GetOptions)` 方法来获取该 Pod 的一系列信息。Pod 有那些信息可以获取呢？看下 Pod 的结构体定义。

```go
type Pod struct {
	metav1.TypeMeta `json:",inline"`
	// Standard object's metadata.
	metav1.ObjectMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`

	// Specification of the desired behavior of the pod.
	Spec PodSpec `json:"spec,omitempty" protobuf:"bytes,2,opt,name=spec"`

	// Most recently observed status of the pod.
	Status PodStatus `json:"status,omitempty" protobuf:"bytes,3,opt,name=status"`
}
```

Pod 信息又包含了三大类型：`metav1.ObjectMeta`、`Spec`、`Status`，每个类型又包含了不同的属性值，像 Name、Namespace、Labels、Annotations 等对象源信息属于 ObjectMeta 这一类，像 Volumes、Containers、Hostname、DNSConfig、RestartPolicy 等详情信息属于 Spec 这一类，像 Phase、 HostIP、PodIP、InitContainerStatuses 等状态信息属于 Status 这一类，我们在取属性信息时，需要找到与之匹配的类型才行，可以分别参考这三大类的结构体定义代码，这里就不在贴出来了。

**参考资料**

- [kubernetes/client-go](https://github.com/kubernetes/client-go)
- [Installing client-go](https://github.com/kubernetes/client-go/blob/master/INSTALL.md)