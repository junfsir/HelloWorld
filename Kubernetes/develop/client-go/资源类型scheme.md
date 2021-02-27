## 介绍

当我们操作资源和 apiserver 进行通信的时候，需要根据资源对象类型的 Group、Version、Kind 以及规范定义、编解码等内容构成 Scheme 类型，然后 Clientset 对象就可以来访问和操作这些资源类型了，Scheme 的定义主要在 api 子项目之中，源码仓库地址: https://github.com/kubernetes/api ，被同步到 Kubernetes 源码的 staging/src/k8s.io/api 之下。

主要就是各种资源对象的原始结构体定义，比如查看 `apps/v1` 目录下面的定义：

```bash
$ tree staging/src/k8s.io/api/apps/v1
staging/src/k8s.io/api/apps/v1
├── BUILD
├── doc.go
├── generated.pb.go
├── generated.proto
├── register.go
├── types.go
├── types_swagger_doc_generated.go
└── zz_generated.deepcopy.go

0 directories, 8 files
```

## **types.go 文件**

其中 `types.go` 文件里面就是 `apps/v1` 这个 `GroupVersion` 下面所有的资源对象的定义，有 Deployment、DaemonSet、StatefulSet、ReplicaSet 等几个资源对象，比如 Deployment 的结构体定义如下所示：

```go
// kubernetes/staging/src/k8s.io/api/apps/v1/types.go
// Deployment enables declarative updates for Pods and ReplicaSets.
type Deployment struct {
	metav1.TypeMeta `json:",inline"`
	// Standard object metadata.
	// +optional
	metav1.ObjectMeta `json:"metadata,omitempty" protobuf:"bytes,1,opt,name=metadata"`

	// Specification of the desired behavior of the Deployment.
	// +optional
	Spec DeploymentSpec `json:"spec,omitempty" protobuf:"bytes,2,opt,name=spec"`

	// Most recently observed status of the Deployment.
	// +optional
	Status DeploymentStatus `json:"status,omitempty" protobuf:"bytes,3,opt,name=status"`
}
```

由 `TypeMeta`、`ObjectMeta`、`DeploymentSpec` 以及 `DeploymentStatus` 4个属性组成，和我们使用 YAML 文件定义的 Deployment 资源对象也是对应的。

```yaml
apiVersion: apps/v1
kind: Deployment  
metadata:
  name:  nginx-deploy
  namespace: default
spec:
  selector:  
    matchLabels:
      app: nginx
  template:  
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
```

其中 `apiVersion` 与 `kind` 就是 `TypeMeta` 属性，metadata 属性就是 `ObjectMeta`，spec 属性就是 `DeploymentSpec`，当资源部署过后也会包含一个 status 的属性，也就是 `DeploymentStatus` ，这样就完整的描述了一个资源对象的模型。

```go
// kubernetes/staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/types.go
// TypeMeta describes an individual object in an API response or request
// with strings representing the type of the object and its API schema version.
// Structures that are versioned or persisted should inline TypeMeta.
//
// +k8s:deepcopy-gen=false
type TypeMeta struct {
	// Kind is a string value representing the REST resource this object represents.
	// Servers may infer this from the endpoint the client submits requests to.
	// Cannot be updated.
	// In CamelCase.
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
	// +optional
	Kind string `json:"kind,omitempty" protobuf:"bytes,1,opt,name=kind"`

	// APIVersion defines the versioned schema of this representation of an object.
	// Servers should convert recognized schemas to the latest internal value, and
	// may reject unrecognized values.
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
	// +optional
	APIVersion string `json:"apiVersion,omitempty" protobuf:"bytes,2,opt,name=apiVersion"`
}

// ObjectMeta is metadata that all persisted resources must have, which includes all objects
// users must create.
type ObjectMeta struct {
	// Name must be unique within a namespace. Is required when creating resources, although
	// some resources may allow a client to request the generation of an appropriate name
	// automatically. Name is primarily intended for creation idempotence and configuration
	// definition.
	// Cannot be updated.
	// More info: http://kubernetes.io/docs/user-guide/identifiers#names
	// +optional
	Name string `json:"name,omitempty" protobuf:"bytes,1,opt,name=name"`

	// GenerateName is an optional prefix, used by the server, to generate a unique
	// name ONLY IF the Name field has not been provided.
	// If this field is used, the name returned to the client will be different
	// than the name passed. This value will also be combined with a unique suffix.
	// The provided value has the same validation rules as the Name field,
	// and may be truncated by the length of the suffix required to make the value
	// unique on the server.
	//
	// If this field is specified and the generated name exists, the server will
	// NOT return a 409 - instead, it will either return 201 Created or 500 with Reason
	// ServerTimeout indicating a unique name could not be found in the time allotted, and the client
	// should retry (optionally after the time indicated in the Retry-After header).
	//
	// Applied only if Name is not specified.
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#idempotency
	// +optional
	GenerateName string `json:"generateName,omitempty" protobuf:"bytes,2,opt,name=generateName"`

	// Namespace defines the space within which each name must be unique. An empty namespace is
	// equivalent to the "default" namespace, but "default" is the canonical representation.
	// Not all objects are required to be scoped to a namespace - the value of this field for
	// those objects will be empty.
	//
	// Must be a DNS_LABEL.
	// Cannot be updated.
	// More info: http://kubernetes.io/docs/user-guide/namespaces
	// +optional
	Namespace string `json:"namespace,omitempty" protobuf:"bytes,3,opt,name=namespace"`

	// SelfLink is a URL representing this object.
	// Populated by the system.
	// Read-only.
	//
	// DEPRECATED
	// Kubernetes will stop propagating this field in 1.20 release and the field is planned
	// to be removed in 1.21 release.
	// +optional
	SelfLink string `json:"selfLink,omitempty" protobuf:"bytes,4,opt,name=selfLink"`

	// UID is the unique in time and space value for this object. It is typically generated by
	// the server on successful creation of a resource and is not allowed to change on PUT
	// operations.
	//
	// Populated by the system.
	// Read-only.
	// More info: http://kubernetes.io/docs/user-guide/identifiers#uids
	// +optional
	UID types.UID `json:"uid,omitempty" protobuf:"bytes,5,opt,name=uid,casttype=k8s.io/kubernetes/pkg/types.UID"`

	// An opaque value that represents the internal version of this object that can
	// be used by clients to determine when objects have changed. May be used for optimistic
	// concurrency, change detection, and the watch operation on a resource or set of resources.
	// Clients must treat these values as opaque and passed unmodified back to the server.
	// They may only be valid for a particular resource or set of resources.
	//
	// Populated by the system.
	// Read-only.
	// Value must be treated as opaque by clients and .
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#concurrency-control-and-consistency
	// +optional
	ResourceVersion string `json:"resourceVersion,omitempty" protobuf:"bytes,6,opt,name=resourceVersion"`

	// A sequence number representing a specific generation of the desired state.
	// Populated by the system. Read-only.
	// +optional
	Generation int64 `json:"generation,omitempty" protobuf:"varint,7,opt,name=generation"`

	// CreationTimestamp is a timestamp representing the server time when this object was
	// created. It is not guaranteed to be set in happens-before order across separate operations.
	// Clients may not set this value. It is represented in RFC3339 form and is in UTC.
	//
	// Populated by the system.
	// Read-only.
	// Null for lists.
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	// +optional
	CreationTimestamp Time `json:"creationTimestamp,omitempty" protobuf:"bytes,8,opt,name=creationTimestamp"`

	// DeletionTimestamp is RFC 3339 date and time at which this resource will be deleted. This
	// field is set by the server when a graceful deletion is requested by the user, and is not
	// directly settable by a client. The resource is expected to be deleted (no longer visible
	// from resource lists, and not reachable by name) after the time in this field, once the
	// finalizers list is empty. As long as the finalizers list contains items, deletion is blocked.
	// Once the deletionTimestamp is set, this value may not be unset or be set further into the
	// future, although it may be shortened or the resource may be deleted prior to this time.
	// For example, a user may request that a pod is deleted in 30 seconds. The Kubelet will react
	// by sending a graceful termination signal to the containers in the pod. After that 30 seconds,
	// the Kubelet will send a hard termination signal (SIGKILL) to the container and after cleanup,
	// remove the pod from the API. In the presence of network partitions, this object may still
	// exist after this timestamp, until an administrator or automated process can determine the
	// resource is fully terminated.
	// If not set, graceful deletion of the object has not been requested.
	//
	// Populated by the system when a graceful deletion is requested.
	// Read-only.
	// More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata
	// +optional
	DeletionTimestamp *Time `json:"deletionTimestamp,omitempty" protobuf:"bytes,9,opt,name=deletionTimestamp"`

	// Number of seconds allowed for this object to gracefully terminate before
	// it will be removed from the system. Only set when deletionTimestamp is also set.
	// May only be shortened.
	// Read-only.
	// +optional
	DeletionGracePeriodSeconds *int64 `json:"deletionGracePeriodSeconds,omitempty" protobuf:"varint,10,opt,name=deletionGracePeriodSeconds"`

	// Map of string keys and values that can be used to organize and categorize
	// (scope and select) objects. May match selectors of replication controllers
	// and services.
	// More info: http://kubernetes.io/docs/user-guide/labels
	// +optional
	Labels map[string]string `json:"labels,omitempty" protobuf:"bytes,11,rep,name=labels"`

	// Annotations is an unstructured key value map stored with a resource that may be
	// set by external tools to store and retrieve arbitrary metadata. They are not
	// queryable and should be preserved when modifying objects.
	// More info: http://kubernetes.io/docs/user-guide/annotations
	// +optional
	Annotations map[string]string `json:"annotations,omitempty" protobuf:"bytes,12,rep,name=annotations"`

	// List of objects depended by this object. If ALL objects in the list have
	// been deleted, this object will be garbage collected. If this object is managed by a controller,
	// then an entry in this list will point to this controller, with the controller field set to true.
	// There cannot be more than one managing controller.
	// +optional
	// +patchMergeKey=uid
	// +patchStrategy=merge
	OwnerReferences []OwnerReference `json:"ownerReferences,omitempty" patchStrategy:"merge" patchMergeKey:"uid" protobuf:"bytes,13,rep,name=ownerReferences"`

	// Must be empty before the object is deleted from the registry. Each entry
	// is an identifier for the responsible component that will remove the entry
	// from the list. If the deletionTimestamp of the object is non-nil, entries
	// in this list can only be removed.
	// Finalizers may be processed and removed in any order.  Order is NOT enforced
	// because it introduces significant risk of stuck finalizers.
	// finalizers is a shared field, any actor with permission can reorder it.
	// If the finalizer list is processed in order, then this can lead to a situation
	// in which the component responsible for the first finalizer in the list is
	// waiting for a signal (field value, external system, or other) produced by a
	// component responsible for a finalizer later in the list, resulting in a deadlock.
	// Without enforced ordering finalizers are free to order amongst themselves and
	// are not vulnerable to ordering changes in the list.
	// +optional
	// +patchStrategy=merge
	Finalizers []string `json:"finalizers,omitempty" patchStrategy:"merge" protobuf:"bytes,14,rep,name=finalizers"`

	// The name of the cluster which the object belongs to.
	// This is used to distinguish resources with same name and namespace in different clusters.
	// This field is not set anywhere right now and apiserver is going to ignore it if set in create or update request.
	// +optional
	ClusterName string `json:"clusterName,omitempty" protobuf:"bytes,15,opt,name=clusterName"`

	// ManagedFields maps workflow-id and version to the set of fields
	// that are managed by that workflow. This is mostly for internal
	// housekeeping, and users typically shouldn't need to set or
	// understand this field. A workflow can be the user's name, a
	// controller's name, or the name of a specific apply path like
	// "ci-cd". The set of fields is always in the version that the
	// workflow used when modifying the object.
	//
	// +optional
	ManagedFields []ManagedFieldsEntry `json:"managedFields,omitempty" protobuf:"bytes,17,rep,name=managedFields"`
}
```

## **zz_generated.deepcopy.go 文件**

上面定义的规范在 Kubernetes 中称为`资源类型 Scheme`，此外`zz_generated.deepcopy.go` 文件是由 `deepcopy-gen` 工具创建的定义各资源类型 `DeepCopyObject()` 方法的文件，所有注册到 Scheme 的资源类型都要实现 `runtime.Object` 接口：

```go
// staging/src/k8s.io/apimachinery/pkg/runtime/interface.go
type Object interface {
	GetObjectKind() schema.ObjectKind
	DeepCopyObject() Object
}
```

而所有的资源类型都包含一个 TypeMeta 类型，而该类型实现了 `GetObjectKind()` 方法，所以各资源类型只需要实现 `DeepCopyObject()` 方法即可：

```go
// staging/src/k8s.io/apimachinery/pkg/apis/meta/v1/meta.go
func (obj *TypeMeta) GetObjectKind() schema.ObjectKind { return obj }
```

各个资源类型的 `DeepCopyObject()` 方法也不是手动定义，而是使用 `deepcopy-gen` 工具命令统一自动生成的，该工具会读取 `types.go` 文件中的 `+k8s:deepcopy-gen` 注释，以 Deployment 为例：

```go
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Deployment enables declarative updates for Pods and ReplicaSets.
type Deployment struct {
......
}
```

然后将自动生成的代码保存到 `zz_generated.deepcopy.go` 文件中。

## **register.go 文件**

`register.go` 文件的主要作用是定义 AddToScheme 函数，将各种资源类型注册到 Clientset 使用的  Scheme 对象中去，由于每个资源自动生成了 DeepCopyObject() 方法，这样资源就实现了 `runtime.Object` 接口，所以可以注册到 Scheme 中去了。

```go
// staging/src/k8s.io/api/apps/v1/register.go
var (
	// TODO: move SchemeBuilder with zz_generated.deepcopy.go to k8s.io/api.
	// localSchemeBuilder and AddToScheme will stay in k8s.io/kubernetes.
	SchemeBuilder      = runtime.NewSchemeBuilder(addKnownTypes)
	localSchemeBuilder = &SchemeBuilder
	// 对外暴露的 AddToScheme 方法用于注册该 Group/Verion 下的所有资源类型
	AddToScheme        = localSchemeBuilder.AddToScheme
)

// staging/src/k8s.io/client-go/kubernetes/scheme/register.go
// 新建一个 Scheme，将各类资源对象都添加到该 Scheme
var Scheme = runtime.NewScheme()  
// 为 Scheme 中的所有类型创建一个编解码工厂
var Codecs = serializer.NewCodecFactory(Scheme)
// 为 Scheme 中的所有类型创建一个参数编解码工厂
var ParameterCodec = runtime.NewParameterCodec(Scheme)
// 将各 k8s.io/api/<Group>/<Version> 目录下资源类型的 AddToScheme() 方法注册到 SchemeBuilder 中
var localSchemeBuilder = runtime.SchemeBuilder{
	......
	appsv1.AddToScheme, 
	appsv1beta1.AddToScheme,
	appsv1beta2.AddToScheme,
	......
}

var AddToScheme = localSchemeBuilder.AddToScheme

func init() {
	v1.AddToGroupVersion(Scheme, schema.GroupVersion{Version: "v1"})
	// 调用 SchemeBuilder 中各资源对象的 AddToScheme() 方法，将它们注册到到 Scheme 对象
	utilruntime.Must(AddToScheme(Scheme))
}
```

将各类资源类型注册到`**全局的 Scheme 对象**`中，这样 Clientset 就可以识别和使用它们了。

apimachinery 子项目主要是 Kubernetes 服务端和客户端项目都共同依赖的一些公共方法、struct、工具类的定义，主要服务于 kubernetes、client-go、apiserver 这三个项目。