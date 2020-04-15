#### NVIDIA device plugin

```
The NVIDIA device plugin for Kubernetes is a Daemonset that allows you to automatically:
Expose the number of GPUs on each nodes of your cluster
Keep track of the health of your GPUs
Run GPU enabled containers in your Kubernetes cluster.
```

#### 安装驱动及cuda

```
nvidia drivers ~=361.93
nvidia cuda toolkit : 官方介绍：The NVIDIA® CUDA® Toolkit provides a development environment for creating high performance GPU-accelerated applications. 
版本跟drivers和GPU架构有关参考：https://github.com/NVIDIA/nvidia-docker/wiki/CUDA#requirements
cuda toolkit安装文档：https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#pre-installation-actions
```

https://blog.csdn.net/xueshengke/article/details/78134991

https://github.com/NVIDIA/k8s-device-plugin

[CentOS7 GPU驱动及CUDA安装](https://wilhelmguo.cn/blog/post/william/Centos-7-安装-Nvidia-GPU-驱动及-CUDA)

#### nvidia-docker2 安装

```
因为GPU属于特定的厂商产品，需要特定的driver，Docker本身并不支持GPU。以前如果要在Docker中使用GPU，就需要在container中安装主机上使用GPU的driver，然后把主机上的GPU设备（例如：/dev/nvidia0）映射到container中。所以这样的Docker image并不具备可移植性。
Nvidia-docker项目就是为了解决这个问题，它让Docker image不需要知道底层GPU的相关信息，而是通过启动container时mount设备和驱动文件来实现的。
```

安装nvidia-docker 2.0的条件

```
GNU/Linux x86_64 with kernel version > 3.10
Docker >= 1.12
NVIDIA GPU with Architecture > Fermi (2.1)
NVIDIA drivers ~= 361.93 (untested on older versions)
Your driver version might limit your CUDA capabilities (see CUDA requirements)
https://github.com/NVIDIA/nvidia-docker/wiki/CUDA#requirements
```

安装

```shell
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.repo | \
sudo tee /etc/yum.repos.d/nvidia-docker.repo
sudo yum install -y nvidia-docker2
sudo pkill -SIGHUP dockerd  
docker run --runtime=nvidia --rm nvidia/cuda:9.0-base nvidia-smi
```

#### 配置docker runtime

```shell
sudo tee /etc/docker/daemon.json <<EOF
	{
                    "default-runtime": "nvidia",  
		"runtimes": {
			"nvidia": {
				"path": "/usr/bin/nvidia-container-runtime",
				"runtimeArgs": []
			}
		}
	}
EOF
sudo pkill -SIGHUP dockerd
```

验证nvidia driver and runtime

```shell
nvidia-container-cli --load-kmods info
```

running GPU container

```shell
docker run -it --runtime=nvidia --shm-size=1g -e NVIDIA_VISIBLE_DEVICES=0 --rm nvcr.io/nvidia/pytorch:18.05-py3
```

#### k8s配置

kubernetes version 1.11

```
the device plugin feature is beta as of Kubernetes v1.11.
```


部署NVIDIA device plugin(DaemonSet) 在整个Kubernetes 系统中，feature-gates 里面特定的 alpha 特性参数 Accelerators 必须设置为 true：--feature-gates="Accelerators=true"

```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nvidia-device-plugin-daemonset
  namespace: kube-system
spec:
  template:
    metadata:
      # Mark this pod as a critical add-on; when enabled, the critical add-on scheduler
      # reserves resources for critical add-on pods so that they can be rescheduled after
      # a failure.  This annotation works in tandem with the toleration below.
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ""
      labels:
        name: nvidia-device-plugin-ds
    spec:
      tolerations:
      # Allow this pod to be rescheduled while the node is in "critical add-ons only" mode.
      # This, along with the annotation above marks this pod as a critical add-on.
      - key: CriticalAddonsOnly
        operator: Exists
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
      containers:
      - image: nvidia/k8s-device-plugin:1.11
        name: nvidia-device-plugin-ctr
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
```

### 测试

如果节点的 Capacity 属性中没有出现 NIVIDA GPU 的数量，有可能是驱动没有安装或者安装失败，请尝试重新安装

running GPU jobs

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
    - name: cuda-container
      image: nvidia/cuda:9.0-devel
      resources:
        limits:
          nvidia.com/gpu: 2 # requesting 2 GPUs
    - name: digits-container
      image: nvidia/digits:6.0
      resources:
        limits:
          nvidia.com/gpu: 2 # requesting 2 GPUs
```



### 遇到的问题

#### 配置feature-gates

```
在GPU NODE上
vim /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_EXTRA_ARGS=--feature-gates=Accelerators=true"
```

#### nvidia-docker2包安装

```
错误：软件包：nvidia-docker2-2.0.3-1.docker18.09.0.ce.noarch (nvidia-docker)
          需要：docker-ce = 3:18.09.0
          已安装: docker-ce-18.03.1.ce-1.el7.centos.x86_64 (installed)
              docker-ce = 18.03.1.ce-1.el7.centos
 您可以尝试添加 --skip-broken 选项来解决该问题
** 发现 1 个已存在的 RPM 数据库问题， 'yum check' 输出如下：
3:dkms-nvidia-410.48-1.el7.x86_64 有已安装冲突 nvidia-kmod: 3:dkms-nvidia-410.48-1.el7.x86_64

yum install  nvidia-docker2-2.0.3-1.docker18.03.1.ce.noarch
```

#### defalult runtime

kubectl logs nvidia-device-plugin-daemonset-ddvcs -nkube-system

```
Failed to initialize NVML: could not load NVML library.
```

/etc/docker/daemon.json 文件缺少 "default-runtime": "nvidia",

```
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
```

#### kernel-delvel kernel-header包安装

cuda ToolKit 文档要求安装 kernel-devel kernel-header 4.4.147版本，找不到这个版本的包，暂时装的3.10版本的包。

```
kernel-devel-4.4.147-1.el7.elrepo.x86_64 
kernel-headers-4.4.147-1.el7.elrepo.x86_64
```

---

```
共享GPU的方案：向apiserver虚报GPU数量
https://github.com/Deepomatic/shared-gpu-nvidia-k8s-device-plugin
缺点：
	1.分配给pod的gpu资源不知道如何共享底层的GPU 
	2.当一个Node上有多个GPU时，为一个pod分配多个GPU没有意义，因为不能保证分配的多个GPU是来自不同的真实的GPU
	3.需要调试到指定的GPU机器上，配合CPU/memory 间接调度。
```

[GPU Sharing Scheduler for Kubernetes Cluster](https://github.com/AliyunContainerService/gpushare-scheduler-extender)

---

文档

[官方中文文档](https://kubernetes.io/zh/docs/tasks/manage-gpus/scheduling-gpus/)

https://blog.csdn.net/u013531940/article/details/79674792

[nivada-docker 的安装](https://github.com/NVIDIA/nvidia-docker)

[nvidia-container-runtime](https://github.com/nvidia/nvidia-container-runtime#docker-engine-setup)

[nivida driver (cuda ToolKit) 安装](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#redhat-installation)

[nivdia k8s-device-plugin 官方文档](https://github.com/NVIDIA/k8s-device-plugin#prerequisites)

[nivdia k8s-device-plugin 中文文档](https://my.oschina.net/jxcdwangtao/blog/1793656)

[Enabling GPUs in the Container Runtime Ecosystem](https://devblogs.nvidia.com/gpu-containers-runtime/)

