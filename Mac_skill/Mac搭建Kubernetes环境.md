### 下载软件包

[docker官网](https://www.docker.com/products/docker-desktop)下载符合要求的软件包，并进行安装；

### 启动Kubernetes

- 因为墙的原因，通过直接安装的方式镜像会较难下载，所以需要先加载镜像至本地，可参考[k8s-for-docker-desktop](https://github.com/AliyunContainerService/k8s-for-docker-desktop)进行；
- 待镜像全部加载完成后，切换至`Preferences --> Kubernetes `选择

- [x] Enable Kubernetes
- [x] Show system containers(advanced)

然后`Apply&Restart`安装即可；