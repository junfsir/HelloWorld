#/bin/bash
# upgrade the kubernetes cluster from single master to ha master
# etcd is out of cluster
# kubernetes version v1.10.5
# refer：https://github.com/lentil1016/kubeadm-ha
source ./cluster-info 

echo """
cluster-info:
  master-00:        ${CP0_IP}
                    ${CP0_HOSTNAME}
  master-01:        ${CP1_IP}
                    ${CP1_HOSTNAME}
  master-02:        ${CP2_IP}
                    ${CP2_HOSTNAME}
  VIP:              ${VIP}
"""
echo -n 'Operating start'

mkdir -p ~/ikube/tls

HOSTS=(${CP0_HOSTNAME} ${CP1_HOSTNAME} ${CP2_HOSTNAME})
IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP})

PRIORITY=(100 50 30)
STATE=("MASTER" "BACKUP" "BACKUP")
HEALTH_CHECK=""
for index in 0 1 2; do
  HEALTH_CHECK=${HEALTH_CHECK}"""
    real_server ${IPS[$index]} 6443 {
        weight 1
        SSL_GET {
            url {
              path /healthz
              status_code 200
            }
            connect_timeout 3
            nb_get_retry 3
            delay_before_retry 3
        }
    }
"""
done

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  echo """
global_defs {
   router_id LVS_DEVEL
}

vrrp_instance VI_1 {
    state ${STATE[${index}]}
    interface ${NET_IF}
    virtual_router_id 69
    priority ${PRIORITY[${index}]}
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass k8sha
    }
    virtual_ipaddress {
        ${VIP}
    }
}

virtual_server ${VIP} 6443 {
    delay_loop 6
    lb_algo loadbalance
    lb_kind DR
    nat_mask 255.0.0.0
    persistence_timeout 0
    protocol TCP

${HEALTH_CHECK}
}
""" > ~/ikube/keepalived-${index}.conf
  scp ~/ikube/keepalived-${index}.conf ${ip}:/etc/keepalived/keepalived.conf

  ssh ${ip} "
    systemctl restart keepalived"

  echo """
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
kubernetesVersion: v1.10.5
apiServerCertSANs:
- ${CP0_IP}
- ${CP1_IP}
- ${CP2_IP}
- ${CP0_HOSTNAME}
- ${CP1_HOSTNAME}
- ${CP2_HOSTNAME}
- ${VIP}
etcd:
  endpoints:
  - http://${ENDPOINTS}:2379
networking:
  podSubnet: "10.244.0.1/16"
""" > ~/ikube/kubeadm-config-m${index}.yaml

  scp ~/ikube/kubeadm-config-m${index}.yaml ${ip}:/etc/kubernetes/kubeadm-config.yaml
done

pushd /etc/kubernetes;
    rm admin.conf controller-manager.conf kubelet.conf scheduler.conf pki/apiserver.crt pki/apiserver.key
    # Generates an API server serving certificate and key
    kubeadm alpha phase certs apiserver --config /etc/kubernetes/kubeadm-config.yaml
    # Generates all kubeconfig files necessary to establish the control plane and the admin kubeconfig file
    kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml 
    echo "Restarting apiserver/controller/scheduler containers."
    docker ps|grep -E 'k8s_kube-scheduler|k8s_kube-controller-manager|k8s_kube-apiserver'|awk '{print $1}'|xargs -i docker rm -f {} > /dev/null
    systemctl restart kubelet
    cp /etc/kubernetes/admin.conf ~/.kube/config
popd

for index in 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  ssh ${ip} "mkdir -p ~/.kube"
  scp /etc/kubernetes/pki/ca.crt ${ip}:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key ${ip}:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key ${ip}:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub ${ip}:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt ${ip}:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key ${ip}:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/admin.conf ${ip}:/etc/kubernetes/admin.conf
  scp /etc/kubernetes/admin.conf ${ip}:~/.kube/config

  ssh ${ip} "
    kubeadm alpha phase certs all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig controller-manager --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig scheduler --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase kubeconfig kubelet --config /etc/kubernetes/kubeadm-config.yaml
    systemctl restart kubelet
    kubeadm alpha phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase controlplane all --config /etc/kubernetes/kubeadm-config.yaml
    kubeadm alpha phase mark-master --config /etc/kubernetes/kubeadm-config.yaml"
done

for index in 0 1 2; do
  host=${HOSTS[${index}]}
  ip=${IPS[${index}]}
  ssh ${ip} "sed -i 's/${CP0_IP}/${VIP}/g' ~/.kube/config"
  ssh ${ip} "sed -i 's/${ip}/${VIP}/g' /etc/kubernetes/kubelet.conf; systemctl restart kubelet"
done

echo

kubectl get cs
kubectl get nodes
kubectl get pods -n kube-system

echo """
join command:
  `kubeadm token create --print-join-command`"""