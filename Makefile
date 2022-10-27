
.PHONY: info

get-nodes:
	@kubectl --kubeconfig /etc/kubernetes/admin.conf  get nodes


info:
	@echo "make info"

system-update:
	@dnf install net-tools -y
	@dnf -y upgrade

disable-selinux:
	@setenforce 0
	@sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

kernel-modules:
	@echo overlay>/etc/modules-load.d/containerd.conf
	@echo br_netfilter>>/etc/modules-load.d/containerd.conf
	@modprobe overlay
	@modprobe br_netfilter

firewall-rules:
	@firewall-cmd --add-masquerade --permanent
	@firewall-cmd --reload

system-rules:
	@echo 'net.bridge.bridge-nf-call-ip6tables=1'>/etc/sysctl.d/k8s.conf
	@echo 'net.bridge.bridge-nf-call-iptables=1'>>/etc/sysctl.d/k8s.conf
	@echo 'net.ipv4.ip_forward=1'>>/etc/sysctl.d/k8s.conf


restart-system-rules:
	@sysctl --system

swap-off:
	@swapoff -a

docker-repo-add:
	@dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo

docker-install:
	@dnf install docker-ce --nobest -y

docker-start:
	@systemctl start docker

docker-enable:
	@systemctl enable docker

docker-restart:
	@systemctl restart docker

docker-cgroups:
	@mkdir /etc/docker -p
	@echo {> /etc/docker/daemon.json
	@echo '"exec-opts": ["native.cgroupdriver=systemd"] '>>/etc/docker/daemon.json
	@echo }>> /etc/docker/daemon.json

kuberneties-repo-add:
	@echo [kubernetes]> /etc/yum.repos.d/kubernetes.repo
	@echo name=Kubernetes>>  /etc/yum.repos.d/kubernetes.repo
	@echo 'baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-$$basearch'>>  /etc/yum.repos.d/kubernetes.repo
	@echo enabled=1>>  /etc/yum.repos.d/kubernetes.repo
	@echo gpgcheck=1>>  /etc/yum.repos.d/kubernetes.repo
	@echo repo_gpgcheck=1>>  /etc/yum.repos.d/kubernetes.repo
	@echo gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg>>  /etc/yum.repos.d/kubernetes.repo
	@echo exclude=kubelet kubeadm kubectl>>  /etc/yum.repos.d/kubernetes.repo

kuberneties-bin-install:
	@dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes


containerd-config-update:
	@mkdir -p /etc/containerd
	@containerd config default > /etc/containerd/config.toml
	@sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml


containerd-restart:
	@systemctl restart containerd

kubelet-enable:
	@systemctl enable kubelet

kubelet-start:
	@systemctl start kubelet



preqs: system-update disable-selinux kernel-modules firewall-rules system-rules \
       restart-system-rules swap-off docker-repo-add docker-install docker-cgroups \
	   containerd-config-update containerd-restart \
	   docker-start docker-enable  kuberneties-repo-add kuberneties-bin-install \
	    kubelet-enable 
	   
#	   kubelet-enable kubelet-start



# MASTER ONLY

k8-master-pull-images:
	@kubeadm config images pull

k8-master-firewall-rules:
	@firewall-cmd --zone=public --permanent --add-port={6443,2379,2380,10250,10251,10252}/tcp
	@firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=10.7.0.0/24 accept'
	@firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=172.17.0.0/16 accept'
	@firewall-cmd --zone=public --permanent --add-rich-rule 'rule family=ipv4 source address=192.168.0.0/16 accept'
	@firewall-cmd --reload
	
k8-master-config:
	@echo "# kubeadm-config.yaml">kubeadm-config.yaml
	@echo "kind: ClusterConfiguration">>kubeadm-config.yaml
	@echo "apiVersion: kubeadm.k8s.io/v1beta3">>kubeadm-config.yaml
	@echo "kubernetesVersion: v1.25.3">>kubeadm-config.yaml
	@echo "---">>kubeadm-config.yaml
	@echo "kind: KubeletConfiguration">>kubeadm-config.yaml
	@echo "apiVersion: kubelet.config.k8s.io/v1beta1">>kubeadm-config.yaml
	@echo "cgroupDriver: systemd">>kubeadm-config.yaml


k8-master-init:
	@kubeadm init --config=kubeadm-config.yaml >/root/kubeadm-init.log


user-config:
	@mkdir -p $$HOME/.kube
	@cp -i /etc/kubernetes/admin.conf $$HOME/.kube/config
	@chown $(id -u):$(id -g) $$HOME/.kube/config
	@export KUBECONFIG=/$$HOME/.kube/config

calico:
	kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

taint-master:
	@kubectl taint nodes --all node-role.kubernetes.io/master-

k8-master:  k8-master-firewall-rules k8-master-pull-images  k8-master-config k8-master-init user-config calico


worker-cmd:
	@cat kubeadm-init.log  | tail -n 2>worker_join.sh
	@cat worker_join.sh

# worker nodes
firewall-worker:
	@firewall-cmd --zone=public --permanent --add-port={10250,30000-32767}/tcp
	@firewall-cmd --reload

reset:
	@kubeadm reset
	@rm -rf /etc/cni/net.d