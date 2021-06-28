### 安装Central

1. 配置helm仓库

```shell
# helm repo add rhacs https://mirror.openshift.com/pub/rhacs/charts/
# helm repo update
# helm search repo -l rhacs/
```

2. 安装Central

```shell
# 可通过--version安装指定版本
# helm install -n stackrox --create-namespace stackrox-central-services rhacs/central-services --set imagePullSecrets.username= --set imagePullSecrets.password=  --set central.exposure.route.enabled=true
# 执行成功之后按照提示执行如下指令、
# oc annotate namespace/stackrox --overwrite openshift.io/node-selector=""
```

> 注意：安装组件时存储最好选择块存储或对象存储，笔者在安装过程中最开始使用nfs，会出现数据库组件不可用的情况；
>
> 另外，组件默认提供HTTPS服务，需提供证书，若不提供则其自己生成
>
> helm install -n stackrox --create-namespace \
>   stackrox-central-services rhacs/central-services \
>   --set imagePullSecrets.allowNone=true \
>   --set central.exposure.loadBalancer.enabled=true \
>   --set-file central.defaultTLS.cert=/path/to/tls-cert.pem \
>   --set-file central.defaultTLS.key=/path/to/tls-key.pem

3. 查看组件

```shell
# 安装成功后会有以下组件
NAME                               READY   STATUS    RESTARTS   AGE
central-98d8f974-rfn76             1/1     Running   0          3h33m
scanner-68d6fc96b-gzml8            1/1     Running   0          2d23h
scanner-68d6fc96b-wktfh            1/1     Running   0          2d23h
scanner-db-cf6d44644-tjtvx         1/1     Running   0          2d23h
```

### 安装Secured Cluster Services

#### 创建 init bundle:

1. Navigate to **Platform Configuration** > **Integrations**.
2. Under the **Authentication Tokens** section, select **Cluster Init Bundle**.
3. Select **Generate Bundle** (add icon **+**) on the top right.
4. Enter a name for the cluster init bundle and select **Generate**.
5. Select **Download Helm Values File** to download the generated bundle.

#### 创建 helm values:

1. Navigate to **Platform Configuration** > **Clusters**.
2. Select **New Cluster** on the top right.
3. Enter a **Cluster Name**.
4. Select a **Cluster Type**.
5. Enter a **Main Image Repository**
6. Enter a Central API Endpoint. If you are installing on the same cluster as Central, you may accept the defaults.
7. Select a **Collection Method**. Typically, the default Kernel Module may be used.
8. Enter a **Collector Image repository**
9. Select the events you’d like to listen for on Admission Controller.
10. Select if you’d like to **Enable Taint Tolerations**. Typically, the default may be used.
11. Select if you’d like to enable the **Slim Collector Mode**. Typically, the default may be used.
12. Input your default image registry
13. Select if you’d like to enforce on object creates and updates. If you don’t select these, deploy time enforcement won’t be enabled.
14. Input a timeout if needed.
15. Select if you’d like to you’d like to **Contact Image Scanners**. If you set this option to true, the admission control service requests an image scan before making an admission decision. Since image scans take several seconds, we recommend that you enable this option only if you can ensure that all images used in your cluster are scanned before deployment
16. Select if you’d like to **Disable Use of Bypass Annotation**. This setting will disable the ability to bypass admission control.
17. Select **Next** in the top right corner.
18. Select **Download Helm Values File** to download the cluster configuration.
19. Run the following command to deploy a sensor:

如果镜像仓库不需要认证或者已经在操作集群安装了Central ，则执行：

```bash
 helm install -n stackrox --create-namespace stackrox-secured-cluster-services rhacs/secured-cluster-services \
  -f <name-of-cluster-init-bundle.yaml> \
  -f <name-of-helm-values-file> \
  --set imagePullSecrets.allowNone=true
```

如果镜像仓库需要认证，则执行：

```bash
 helm install -n stackrox --create-namespace stackrox-secured-cluster-services rhacs/secured-cluster-services \
  -f <name-of-cluster-init-bundle.yaml> \
  -f <name-of-helm-values-file> \
  --set imagePullSecrets.username=<username> --set imagePullSecrets.password=<password>
```

> 查看admin密码
>
> oc -n stackrox get secret $(oc get secrets |grep stackrox-generated |awk '{print $1}') -o go-template='{{ index .data "generated-values.yaml" }}' | base64 --decode 

### Refer

[quick-start-with-helm](https://help.stackrox.com/docs/get-started/quick-start-helm/)