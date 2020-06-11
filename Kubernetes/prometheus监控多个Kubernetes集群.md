`Prometheus` 显然已经成为了`Kubernetes`的监控标准，其只需要结合`node_exporter`和`kube-state-metrics`可以很方便地实现对`node`及`Pod`的相关指标采集，再结合`alertmanager`及报警发送组件（诸如钉钉、企业微信等）即可实现整个监控、报警生态。最初接触和使用的都是`Prometheus`对单个集群的监控，多个集群则部署多套，极不方便灵活。新入职的公司采用了单套`Prometheus`监控多个集群的方式，这里记一下方案及实现。

#### Prometheus部署

首先是`Prometheus`的部署，最广泛和方便的方式有两种，一种是`Prometheus Operator`，另一种是`kube-prometheus`。二者都可直接通过helm进行部署，极为方便，需要注意的是在`install`之前需要修改监控数据落地的位置，即指定`storageclass`、创建`PersistentVolume`，这些完成之后即可一键安装。`Operator`相对原始的方式来说很方便，因为它对原来的资源做了更高层的封装，可直接`create`对应的的`crd`，而不需要再修改配置文件。

下面记录一下`kube-prometheus`的安装过程：

1. **创建sc：**

```yaml
# cat prometheus-sc.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: prom-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```

2. **创建pv：**

```yaml
# cat prometheus-pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-localvolume
spec:
  capacity:
    storage: 20Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: prom-storage
  local:
    path: /data/prometheus-storage/
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          # 将此处值修改为具体的监控数据存储节点
          - docker-0-203
```

3. 下载chart并做个性化修改

```shell
# helm fetch stable/prometheus
```

4. 安装

```shell
# tar xf prometheus-5.4.0.tgz
# cd prometheus

# vim values.yaml
# 将.server.storageClass修改为prom-storage

# 修改完成之后，执行以下命令安装
# cd ../
# helm install -f ./prometheus/values.yaml --name pro2 --namespace prometheus ./prometheus/
```

#### 监控多集群

需要解决2个问题：

1. 设置好` kubernetes_sd_configs`，让其可通过其它k8s集群的apiserver发现抓取的endpionts。
2. 设置好`relabel_configs`，构造出访问其它k8s集群中的service, pod, node等endpoint URL。

##### 构造apiserver连接信息

解决问题1还是比较简单的，设置` kubernetes_sd_configs`时填入其它k8s信息的api_server、ca_file、bearer_token_file即可。

得到其它apiserver的ca_file、bearer_token_file方法如下：

```bash
# 创建一个叫admin的serviceaccount
kubectl -n kube-system create serviceaccount admin
# 给这个admin的serviceaccount绑上cluser-admin的clusterrole
kubectl -n kube-system create clusterrolebinding sa-cluster-admin --serviceaccount kube-system/admin --clusterrole cluser-admin
# 查询admin的secret
kubectl -n kube-system get serviceaccounts admin -o yaml | yq r - secrets[0].name
# 查询admin的secret详细信息，这里的admin-token-vtrt6是上面的命令查询出来的
kubectl -n kube-system get secret admin-token-vtrt6 -o yaml
# 获取bearer_token的内容
kubectl -n kube-system get secret admin-token-vtrt6 -o yaml | yq r - data.token|base64 -d
```

上面这段关于`ServiceAccount`、`ClusterRoleBinding`、`Secret`的操作原理见[Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)和[Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)。

得到bearer_token内容后，将其保存进文件，就可以设置`kubernetes_sd_configs`了，如下：

```yaml
kubernetes_sd_configs:
  - role: endpoints
    api_server: https://9.77.11.236:8443
    tls_config:
      insecure_skip_verify: true
    bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
```

##### 构造出访问其它k8s集群中的service, pod, node等endpoint URL

经调研，发现外部可通过k8s的apiserver proxy机制很轻松地访问其它k8s集群内部的service、pod、node，参见[Manually constructing apiserver proxy URLs](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#manually-constructing-apiserver-proxy-urls)，因此在外部访问其它k8s集群内的地址构造成如下这样就可以了：

```
https://${other_apiserver_address}/api/v1/nodes/node_name:[port_name]/proxy/metrics
https://${other_apiserver_address}/api/v1/namespaces/service_namespace/services/http:service_name[:port_name]/proxy/metrics
https://${other_apiserver_address}/api/v1/namespaces/pod_namespace/pods/http:pod_name[:port_name]/proxy/metrics
```

最终整理出的relabel_configs配置如下：

```yaml
- job_name: 'kubernetes-apiservers-other-cluster'
  kubernetes_sd_configs:
    - role: endpoints
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
      action: keep
      regex: default;kubernetes;https
    - target_label: __address__
      replacement: ${other_apiserver_address}
- job_name: 'kubernetes-nodes-other-cluster'
  kubernetes_sd_configs:
    - role: node
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics
- job_name: 'kubernetes-nodes-cadvisor-other-cluster'
  kubernetes_sd_configs:
    - role: node
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - action: labelmap
      regex: __meta_kubernetes_node_label_(.+)
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_node_name]
      regex: (.+)
      target_label: __metrics_path__
      replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
- job_name: 'kubernetes-kube-service-endpoints-other-cluster'
  kubernetes_sd_configs:
    - role: endpoints
      api_server: https://${other_apiserver_address}
      tls_config:
        insecure_skip_verify: true
      bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  tls_config:
    insecure_skip_verify: true
  bearer_token: 'eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJ....j5ASEVs6epJVeQ'
  scheme: https
  relabel_configs:
    - source_labels: [__meta_kubernetes_service_label_component]
      action: keep
      regex: '^(node-exporter|kube-state-metrics)$'
    - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
      action: keep
      regex: true
    - source_labels: [__address__]
      action: replace
      target_label: instance
    - target_label: __address__
      replacement: ${other_apiserver_address}
    - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_pod_name, __meta_kubernetes_pod_container_port_number]
      regex: ([^;]+);([^;]+);([^;]+)
      target_label: __metrics_path__
      replacement: /api/v1/namespaces/${1}/pods/http:${2}:${3}/proxy/metrics
    - action: labelmap
      regex: __meta_kubernetes_service_label_(.+)
    - source_labels: [__meta_kubernetes_namespace]
      action: replace
      target_label: kubernetes_namespace
    - source_labels: [__meta_kubernetes_service_name]
      action: replace
      target_label: kubernetes_name
```

refer

[使用prometheus监控多k8s集群](https://jeremyxu2010.github.io/2018/11/使用prometheus监控多k8s集群/)