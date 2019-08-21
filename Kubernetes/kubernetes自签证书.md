### 证书标准

**X.509** - 这是一种证书标准,主要定义了证书中应该包含哪些内容.其详情可以参考RFC5280,SSL使用的就是这种证书标准.

### 编码格式

同样的X.509证书,可能有不同的编码格式,目前有以下两种编码格式.

**PEM** - Privacy Enhanced Mail,打开看文本格式,以"-----BEGIN..."开头, "-----END..."结尾,内容是BASE64编码.
查看PEM格式证书的信息:`openssl x509 -in certificate.pem -text -noout`
Apache和*NIX服务器偏向于使用这种编码格式.

**DER** - Distinguished Encoding Rules,打开看是二进制格式,不可读.
查看DER格式证书的信息:`openssl x509 -in certificate.der -inform der -text -noout`
Java和Windows服务器偏向于使用这种编码格式.

### 相关的文件扩展名

这是比较误导人的地方,虽然我们已经知道有PEM和DER这两种编码格式,但文件扩展名并不一定就叫"PEM"或者"DER",常见的扩展名除了PEM和DER还有以下这些,它们除了编码格式可能不同之外,内容也有差别,但大多数都能相互转换编码格式.

**CRT** - CRT应该是certificate的三个字母,其实还是证书的意思,常见于*NIX系统,有可能是PEM编码,也有可能是DER编码,大多数应该是PEM编码,相信你已经知道怎么辨别.

**CER** - 还是certificate,还是证书,常见于Windows系统,同样的,可能是PEM编码,也可能是DER编码,大多数应该是DER编码.

**KEY** - 通常用来存放一个公钥或者私钥,并非X.509证书,编码同样的,可能是PEM,也可能是DER.
查看KEY的办法:`openssl rsa -in mykey.key -text -noout`
如果是DER格式的话,同理应该这样了:`openssl rsa -in mykey.key -text -noout -inform der`

**CSR** - Certificate Signing Request,即证书签名请求,这个并不是证书,而是向权威证书颁发机构获得签名证书的申请,其核心内容是一个公钥(当然还附带了一些别的信息),在生成这个申请的时候,同时也会生成一个私钥,私钥要自己保管好.做过iOS APP的朋友都应该知道是怎么向苹果申请开发者证书的吧.
查看的办法:`openssl req -noout -text -in my.csr` (如果是DER格式的话照旧加上-inform der,这里不写了)

**PFX/P12** - predecessor of PKCS#12,对*nix服务器来说,一般CRT和KEY是分开存放在不同文件中的,但Windows的IIS则将它们存在一个PFX文件中,(因此这个文件包含了证书及私钥)这样会不会不安全？应该不会,PFX通常会有一个"提取密码",你想把里面的东西读取出来的话,它就要求你提供提取密码,PFX使用的时DER编码,如何把PFX转换为PEM编码？
`openssl pkcs12 -in for-iis.pfx -out for-iis.pem -nodes`
这个时候会提示你输入提取代码. for-iis.pem就是可读的文本.
生成pfx的命令类似这样：`openssl pkcs12 -export -in certificate.crt -inkey privateKey.key -out certificate.pfx -certfile CACert.crt`

其中CACert.crt是CA(权威证书颁发机构)的根证书,有的话也通过-certfile参数一起带进去.这么看来,PFX其实是个证书密钥库.

**JKS** - 即Java Key Storage,这是Java的专利,跟OpenSSL关系不大,利用Java的一个叫"keytool"的工具,可以将PFX转为JKS,当然了,keytool也能直接生成JKS,不过在此就不多表了.

---

SSL/TLS协议的基本思路是采用[公钥加密法](http://en.wikipedia.org/wiki/Public-key_cryptography)，也就是说，客户端先向服务器端索要公钥，然后用公钥加密信息，服务器收到密文后，用自己的私钥解密。

---

HTTPS证书验证流程（极简化版）
    1.客户端向服务端请求证书（server.crt）；
    2.服务端下发证书（server.crt）；
    3.客户端用预制的受信任机构的证书（ca.crt）来验证服务端下发的证书（server.crt）是否合法，并且还会校验下发下来的证书里的域名与要请求的域名是否一致；
 【以下步骤开启双向验证后才会触发】

    4. 客户端选择一个由受信任的机构（ca.crt）颁发的证书（client.crt）发送给服务端；
    5. 服务端用预制的受信任机构的证书（ca.crt）来验证客户端传来的证书（client.crt）是否合法；

### 自签证书

1. 12个自签证书

使用cfssl工具

安装：go get -u github.com/cloudflare/cfssl/cmd/...

- 两个自签CA

```
mkdir kubernetes
cd kubernetes
cat << EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
          "signing",
          "key encipherment",
          "server auth",
          "client auth"
        ],
        "expiry": "8760h"
      },
      "server": {
        "usages": [
            "digital signature",
            "key encipherment",
            "server auth"
        ],
        "expiry": "8760h"
      },
      "client": {
        "usages": [
            "digital signature",
            "key encipherment",
            "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
EOF
cat << EOF > ca-csr.json
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048 
    },  
    "ca": {
        "expiry": "87600h"
    }   
}
EOF
cfssl genkey -initca ca-csr.json | cfssljson -bare ca
cd ..
生成ca.csr ca.pem ca-key.pem
将ca.pem 拷贝到/etc/kuebernetes/pki/ca.crt
将ca-key.pem 拷贝到/etc/kuebernetes/pki/ca.key

mkdir front-proxy-ca
cd front-proxy-ca
自签front-proxy-ca CA操作过程同上，将kubernetes换成 front-proxy-ca即可
cd .. 
将ca.pem 拷贝到/etc/kuebernetes/pki/front-proxy-ca.crt
将ca-key.pem 拷贝到/etc/kuebernetes/pki/front-proxy-ca.key
```

- apiserver

```
cat <<EOF > apiserver-csr.json 
{
  "CN": "kube-apiserver",
  "hosts": [
    "k8s-dev-0-21",
    "10.204.0.21",
    "10.96.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],  
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/config.json -profile=server apiserver-csr.json | cfssljson -bare apiserver
生成apiserver.pem apiserver.csr apiserver-key.pem
将apiserver.pem 拷贝到/etc/kuebernetes/pki/apiserver.crt
将apiserver-key.pem 拷贝到/etc/kuebernetes/pki/apiserver.key
```

- apiserver-kubelet-client

```
cat << EOF > apiserver-kubelet-client-csr.json
{
  "CN": "kube-apiserver-kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client apiserver-kubelet-client-csr.json | cfssljson -bare apiserver-kubelet-client
生成apiserver-kubelet-client.pem apiserver-kubelet-client.csr apiserver-kubelet-client-key.pem
将apiserver-kubelet-client.pem 拷贝到/etc/kuebernetes/pki/apiserver-kubelet-client.crt
将apiserver-kubelet-client-key.pem 拷贝到/etc/kuebernetes/pki/apiserver-kubelet-client.key
```

- front-proxy-client

```
cat << EOF > front-proxy-client-csr.json
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=front-proxy-ca/ca.pem -ca-key=front-proxy-ca/ca-key.pem --config=front-proxy-ca/ca-config.json -profile=client front-proxy-client-csr.json | cfssljson -bare front-proxy-client
生成front-proxy-client.pem afront-proxy-client.csr front-proxy-client-key.pem
将front-proxy-client.pem 拷贝到/etc/kuebernetes/pki/front-proxy-client.crt
将front-proxy-client-key.pem 拷贝到/etc/kuebernetes/pki/front-proxy-client.key
```

- sa

```
openssl genrsa -out sa.key 2048
openssl rsa -in sa.key -pubout -out sa.pub
将这两个文件拷贝至/etc/kuebernetes/pki/sa.key  /etc/kuebernetes/pki/sq.pub
```

2. 4个kubeconfig文件

- admin.conf

```
cat << EOF > admin-csr.json
{
  "CN": "kubernetes-admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:masters"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes-ca/kubernetes-ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client admin-csr.json | cfssljson -bare admin
KUBECONFIG=admin.conf kubectl config set-cluster kubernetes --server=https://10.204.0.21:6443 --certificate-authority kubernetes/ca.pem --embed-certs
KUBECONFIG=admin.conf kubectl config set-credentials kubernetes-admin --client-key admin-key.pem --client-certificate admin.pem --embed-certs
KUBECONFIG=admin.conf kubectl config set-context kubernetes-admin@kubernetes --cluster kubernetes --user kubernetes-admin
KUBECONFIG=admin.conf kubectl config use-context kubernetes-admin@kubernetes
```

- kubelet.conf

```
cat << EOF > kubelet-csr.json
{
  "CN": "system:node:k8s-dev-0-21",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "O": "system:nodes"
    }
  ]
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client kubelet-csr.json | cfssljson -bare kubelet
KUBECONFIG=kubelet.conf kubectl config set-cluster kubernetes --server=https://10.204.0.21:6443 --certificate-authority kubernetes/ca.pem --embed-certs
KUBECONFIG=kubelet.conf kubectl config set-credentials node:k8s-dev-0-21 --client-key kubelet-key.pem --client-certificate kubelet.pem --embed-certs
KUBECONFIG=kubelet.conf kubectl config set-context system:node:k8s-dev-0-21@kubernetes --cluster kubernetes --user system:node:k8s-dev-0-21
KUBECONFIG=kubelet.conf kubectl config use-context system:node:k8s-dev-0-21@kubernetes
```

- controller.conf

```
cat << EOF > controller-manager-csr.json
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client controller-manager-csr.json | cfssljson -bare controller-manager
KUBECONFIG=controller-manager.conf kubectl config set-cluster kubernetes --server=https://10.204.0.21:6443 --certificate-authority kubernetes/ca.pem --embed-certs
KUBECONFIG=controller-manager.conf kubectl config set-credentials kube-controller-manager --client-key controller-manager-key.pem --client-certificate controller-manager.pem --embed-certs
KUBECONFIG=controller-manager.conf kubectl config set-context system:kube-controller-manager@kubernetes --cluster kubernetes --user system:kube-controller-manager
KUBECONFIG=controller-manager.conf kubectl config use-context system:kube-controller-manager@kubernetes
```

- scheduler.conf

```
cat << EOF > scheduler-csr.json
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client scheduler-csr.json | cfssljson -bare scheduler
KUBECONFIG=scheduler.conf kubectl config set-cluster kubernetes --server=https://10.204.0.21:6443 --certificate-authority kubernetes/ca.pem --embed-certs
KUBECONFIG=scheduler.conf kubectl config set-credentials kube-scheduler --client-key scheduler-key.pem --client-certificate scheduler.pem --embed-certs
KUBECONFIG=scheduler.conf kubectl config set-context system:kube-scheduler@kubernetes --cluster kubernetes --user kube-scheduler
KUBECONFIG=scheduler.conf kubectl config use-context system:kube-scheduler@kubernetes
```

3. kubelet 证书

cat << EOF　> kubelet-client-csr.json

```
{
  "CN": "system:node:k8s-dev-0-21",
  "key": {
    "algo": "ecdsa",
    "size": 256 
  },  
  "names": [
    {   
      "O": "system:nodes"
    }   
  ]
}
EOF
cfssl gencert -ca=kubernetes/ca.pem -ca-key=kubernetes/ca-key.pem --config=kubernetes/ca-config.json -profile=client kubelet-client-csr.json | cfssljson -bare kubelet-client
生成 kubelet-client-key.pem kubelet-client.pem
将 kubelet-client-key.pem 加到kubelet-client.pem底部
拷贝kubelet-client.pem 到/var/lib/kubelet/pki 
cd /var/lib/kubelet/pki
rm -fr kubelet-client-current.pem
ln -s kubelet-client.pem kubelet-client-current.pem  
```

4. User ClusterRoleBinding

```
kubelet.conf中的用户system:node:k8s-dev-0-21 对系统中的资源权限
cat <<crb.yaml >EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: default-admin
subjects:
- kind: User
  name: system:node:k8s-dev-0-21
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: admin
  apiGroup: rbac.authorization.k8s.io
EOF
kubectl create -f crb.yaml
```

## refer

1. [PKI Certificates and Requirements](https://v1-12.docs.kubernetes.io/docs/setup/certificates/)
2. [/etc/kubernetes/pki 签证书操作](https://gist.github.com/detiber/81b515df272f5911959e81e39137a8bb)
3. [RBAC——基于角色的访问控制]( <https://jimmysong.io/kubernetes-handbook/guide/rbac.html)
4. [user 证书的签法](https://github.com/xizhibei/blog/issues/64)
5. [kubelet bootstrap 流程](https://lingxiankong.github.io/2018-09-18-kubelet-bootstrap-process.html)
6. k8s证书结构： [https://docs.lvrui.io/2018/09/28/%E8%AF%A6%E8%A7%A3kubeadm%E7%94%9F%E6%88%90%E7%9A%84%E8%AF%81%E4%B9%A6/]
7. [详解kubeadm生成的证书](https://docs.lvrui.io/2018/09/28/详解kubeadm生成的证书/)
8. [证书轮换](https://k8smeetup.github.io/docs/tasks/tls/certificate-rotation/)
9. [cfssl 用法](https://blog.51cto.com/liuzhengwei521/2120535)

---

```shell
查看超时
openssl x509 -enddate -noout -in front-proxy-client.crt

查看证书文本信息
openssl x509 -in apiserver-etcd-client.crt -text -noout

重新生成证书
kubeadm alpha phase certs front-proxy-client --config=/usr/local/src/1.10.5/kubeadm-init.yaml

重新生成kubeconfig
rm -rf /etc/kubernetes/*conf
kubeadm alpha phase kubeconfig all --config ~/kube/conf/kubeadm.yaml
cp /etc/kubernetes/admin.conf ~/.kube/config

重新生成bootstrap-token
kubeadm alpha phase bootstrap-token all
```

