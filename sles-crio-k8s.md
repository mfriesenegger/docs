# Using CRI-O and Kubernetes packages built on Open Build Service for SLES

Mike Friesenegger <mikef@suse.com>

Publish Date: October 2, 2020

This document is loosely based on [Installing Kubernetes 1.12 on SUSE Linux using kubeadm](https://developer.ibm.com/storage/2019/03/01/kubernetes-1-12-on-suse-linux-using-kubeadm/).  I want to give credit to the author of the document that started this documentation effort.

Check back occasionally for updates to this document.

## Repositories
### for SLES 15 SP1
Repository: https://download.opensuse.org/repositories/home:/mfriesenegger:/branches:/openSUSE:/Leap:/15.2:/Update/SLE_15_SP1_Backports/

### for SLES 15 SP2
Repository: https://download.opensuse.org/repositories/home:/mfriesenegger:/branches:/openSUSE:/Leap:/15.2:/Update/openSUSE_Backports_SLE-15-SP2_standard/

## Package versions tested
- cri-o-1.17.3-bp152.2.1
- cri-tools-1.18.0-bp152.2.1
- kubernetes-kubelet-1.18.4-bp151.2.5.1
- kubernetes-kubeadm-1.18.4-bp151.2.5.1
- kubernetes-client-1.18.4-bp151.2.5.1

## Architectures tested
- s390x

## Hosts used in this document
- kube-master
  - 192.168.100.10
- kube-work1
  - 192.168.100.11
- kube-work2
  - 192.168.100.12

## Initial hosts setup
1. Install SLES on hosts
1. Configure hostname and IP address
1. Add host entries in /etc/hosts for all hosts
1. Disable apparmor
1. Register and fully patch
1. Add the Containers module
  ```
  SUSEConnect -p sle-module-containers/15.1/s390x
  ```

## Kubernetes master deployment
1. Add the following to the new file /etc/modules-load.d/k8s.conf
  ```
  br_netfilter
  ```
1. Load the following modules
  ```
  modprobe br_netfilter
  ```
1. Add the following to the new file /etc/sysctl.d/k8s.conf
  ```
  net.ipv4.ip_forward = 1
  net.ipv4.conf.all.forwarding = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  ```
1. Read values from all system directories
   ```
   sysctl -p /etc/sysctl.d/k8s.conf
   ```
1. Add the appropriate Open Build Service repo from the Repositories listed above
   ```
   zypper ar -fc <repository URL> k8s
   ```
   **NOTE:** Trust always
   ```
   zypper ref
   ```
1. Install packages
  ```
  zypper in cri-o kubernetes-kubeadm kubernetes-kubelet kubernetes-client
  ```
  A portion of the zypper command output is below
  ```
  Loading repository data...
  Reading installed packages...
  Resolving package dependencies...

  The following 32 NEW packages are going to be installed:
    apparmor-abstractions apparmor-docs apparmor-parser apparmor-parser-lang apparmor-profiles apparmor-utils apparmor-utils-lang cni
    cni-plugins conmon conntrack-tools cri-o cri-o-kubeadm-criconfig cri-tools kubernetes1.17-kubelet kubernetes1.18-client
    kubernetes1.18-kubeadm kubernetes1.18-kubelet kubernetes1.18-kubelet-common kubernetes-client kubernetes-kubeadm
    kubernetes-kubelet libcontainers-common libnetfilter_cthelper0 libnetfilter_cttimeout1 libnetfilter_queue1 patterns-base-apparmor
    perl-apparmor python3-apparmor runc socat yast2-apparmor

  The following NEW pattern is going to be installed:
    apparmor

  The following 4 recommended packages were automatically selected:
    apparmor-docs apparmor-utils cni-plugins yast2-apparmor

  The following 11 packages have no support information from their vendor:
    cri-o cri-o-kubeadm-criconfig cri-tools kubernetes1.17-kubelet kubernetes1.18-client kubernetes1.18-kubeadm kubernetes1.18-kubelet
    kubernetes1.18-kubelet-common kubernetes-client kubernetes-kubeadm kubernetes-kubelet

  32 new packages to install.
  Overall download size: 127.2 MiB. Already cached: 0 B. After the operation, additional 655.9 MiB will be used.
  ```
  **NOTE:** Run ```systemctl disable apparmor``` because it was enabled during the package installation

1. Enable and start cri-o. Enable kubelet
  ```
  systemctl start crio.service
  systemctl enable crio.service
  systemctl enable kubelet.service
  ```
1. Run kubeadm init to initialize the Kubernetes cluster with the default Flannel pod network cidr
  ```
  kubeadm init --pod-network-cidr=10.244.0.0/16 2>&1 | tee /root/kubeadm-init.log
  ```

  The output of the kubeadm init command should look similiar to what is below
  ```
  I1002 06:40:00.099553    2884 version.go:252] remote version is much newer: v1.19.2; falling back to: stable-1.18
  W1002 06:40:00.359009    2884 configset.go:202] WARNING: kubeadm cannot validate component configs for API groups [kubelet.config.k8s.io kubeproxy.config.k8s.io]
  [init] Using Kubernetes version: v1.18.9
  [preflight] Running pre-flight checks
  [preflight] Pulling images required for setting up a Kubernetes cluster
  [preflight] This might take a minute or two, depending on the speed of your internet connection
  [preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
  [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
  [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
  [kubelet-start] Starting the kubelet
  [certs] Using certificateDir folder "/etc/kubernetes/pki"
  [certs] Generating "ca" certificate and key
  [certs] Generating "apiserver" certificate and key
  [certs] apiserver serving cert is signed for DNS names [kube-master kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.100.10]
  [certs] Generating "apiserver-kubelet-client" certificate and key
  [certs] Generating "front-proxy-ca" certificate and key
  [certs] Generating "front-proxy-client" certificate and key
  [certs] Generating "etcd/ca" certificate and key
  [certs] Generating "etcd/server" certificate and key
  [certs] etcd/server serving cert is signed for DNS names [kube-master localhost] and IPs [192.168.100.10 127.0.0.1 ::1]
  [certs] Generating "etcd/peer" certificate and key
  [certs] etcd/peer serving cert is signed for DNS names [kube-master localhost] and IPs [192.168.100.10 127.0.0.1 ::1]
  [certs] Generating "etcd/healthcheck-client" certificate and key
  [certs] Generating "apiserver-etcd-client" certificate and key
  [certs] Generating "sa" key and public key
  [kubeconfig] Using kubeconfig folder "/etc/kubernetes"
  [kubeconfig] Writing "admin.conf" kubeconfig file
  [kubeconfig] Writing "kubelet.conf" kubeconfig file
  [kubeconfig] Writing "controller-manager.conf" kubeconfig file
  [kubeconfig] Writing "scheduler.conf" kubeconfig file
  [control-plane] Using manifest folder "/etc/kubernetes/manifests"
  [control-plane] Creating static Pod manifest for "kube-apiserver"
  [control-plane] Creating static Pod manifest for "kube-controller-manager"
  W1002 06:40:36.359734    2884 manifests.go:225] the default kube-apiserver authorization-mode is "Node,RBAC"; using "Node,RBAC"
  [control-plane] Creating static Pod manifest for "kube-scheduler"
  W1002 06:40:36.360495    2884 manifests.go:225] the default kube-apiserver authorization-mode is "Node,RBAC"; using "Node,RBAC"
  [etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
  [wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
  [apiclient] All control plane components are healthy after 19.501895 seconds
  [upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
  [kubelet] Creating a ConfigMap "kubelet-config-1.18" in namespace kube-system with the configuration for the kubelets in the cluster
  [upload-certs] Skipping phase. Please see --upload-certs
  [mark-control-plane] Marking the node kube-master as control-plane by adding the label "node-role.kubernetes.io/master=''"
  [mark-control-plane] Marking the node kube-master as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
  [bootstrap-token] Using token: 3xam4s.egyvornnptia0cni
  [bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
  [bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to get nodes
  [bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
  [bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
  [bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
  [bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
  [kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
  [addons] Applied essential addon: CoreDNS
  [addons] Applied essential addon: kube-proxy

  Your Kubernetes control-plane has initialized successfully!

  To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

  You should now deploy a pod network to the cluster.
  Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
    https://kubernetes.io/docs/concepts/cluster-administration/addons/

  Then you can join any number of worker nodes by running the following on each as root:

  kubeadm join 192.168.100.10:6443 --token 3xam4s.egyvornnptia0cni \
      --discovery-token-ca-cert-hash sha256:00b8a1217ed1aad46839001eba0cefe93f1d777839d19cc48fc701fa5da3468b
  ```
1. Copy Kubernetes config file to start using the cluster
  ```
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  ```
1. Verify the cluster info
  ```
  kubectl cluster-info
  ```
  The output of the kubectl command is below
  ```
  Kubernetes master is running at https://192.168.100.10:6443
  KubeDNS is running at https://192.168.100.10:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

  To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

  ```
1. Add flannel for the network layer
  ```
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
  ```
1. Additional kubectl commands with output to review the cluster
  ```
  kubectl version
  Client Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.4", GitCommit:"c96aede7b5205121079932896c4ad89bb93260af", GitTreeState:"clean", BuildDate:"2020-06-22T12:00:00Z", GoVersion:"go1.13.11", Compiler:"gc", Platform:"linux/s390x"}
  Server Version: version.Info{Major:"1", Minor:"18", GitVersion:"v1.18.9", GitCommit:"94f372e501c973a7fa9eb40ec9ebd2fe7ca69848", GitTreeState:"clean", BuildDate:"2020-09-16T13:47:43Z", GoVersion:"go1.13.15", Compiler:"gc", Platform:"linux/s390x"}
  ```
  ```
  kubectl get componentstatuses
  NAME                 STATUS    MESSAGE             ERROR
  scheduler            Healthy   ok                  
  controller-manager   Healthy   ok                  
  etcd-0               Healthy   {"health":"true"}  
  ```
  ```
  kubectl get nodes
  NAME          STATUS   ROLES    AGE     VERSION
  kube-master   Ready    master   5m11s   v1.18.4
  ```
  ```
  kubectl -n kube-system get pods
  NAME                                  READY   STATUS    RESTARTS   AGE
  coredns-66bff467f8-bpdxx              1/1     Running   0          5m4s
  coredns-66bff467f8-fvmnl              1/1     Running   0          5m4s
  etcd-kube-master                      1/1     Running   0          5m16s
  kube-apiserver-kube-master            1/1     Running   0          5m16s
  kube-controller-manager-kube-master   1/1     Running   0          5m15s
  kube-flannel-ds-j2pb5                 1/1     Running   0          36s
  kube-proxy-nrnp2                      1/1     Running   0          5m4s
  kube-scheduler-kube-master            1/1     Running   0          5m15s
  ```
  **NOTE:** Do not proceed until the kube-master is Ready and all pods are Running.

## Kubernetes worker deployment
1. Add the following to the new file /etc/modules-load.d/k8s.conf
  ```
  br_netfilter
  ```
1. Load the following modules
  ```
  modprobe br_netfilter
  ```
1. Add the following to the new file /etc/sysctl.d/k8s.conf
  ```
  net.ipv4.ip_forward = 1
  net.ipv4.conf.all.forwarding = 1
  net.bridge.bridge-nf-call-ip6tables = 1
  net.bridge.bridge-nf-call-iptables = 1
  ```
1. Read values from all system directories
   ```
   sysctl -p /etc/sysctl.d/k8s.conf
   ```
1. Add the appropriate Open Build Service repo from the Repositories listed above
   ```
   zypper ar -fc <repository URL> k8s
   ```
   **NOTE:** Trust always
   ```
   zypper ref
   ```
1. Install packages
   ```
   zypper in kubernetes-kubelet kubernetes-kubeadm
   ```
  **NOTE:** Run ```systemctl disable apparmor``` because it was enabled during the package installation

1. Enable and start cri-o. Enable kubelet
   ```
   systemctl start crio.service
   systemctl enable crio.service
   systemctl enable kubelet.service
   ```
1. Use the command from kubeadm init to join any number of worker nodes to the cluster
   ```
   kubeadm join 192.168.100.10:6443 --token 3xam4s.egyvornnptia0cni \
       --discovery-token-ca-cert-hash sha256:00b8a1217ed1aad46839001eba0cefe93f1d777839d19cc48fc701fa5da3468b
   ```
1. Use kubectl command on kube-master to verify the worker node is Ready
```
kubectl get nodes
NAME          STATUS   ROLES    AGE   VERSION
kube-master   Ready    master   19m   v1.18.4
kube-work1    Ready    <none>   23s   v1.18.4
```
**NOTE:** Repeat _Kubernetes worker deployment_ section for remaining worker nodes

## References
- [KubeVirt on Kubernetes with CRI-O from scratch](https://kubevirt.io/2019/KubeVirt_k8s_crio_from_scratch.html)
