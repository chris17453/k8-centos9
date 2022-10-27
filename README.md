# k8-centos9




## MASTER Node build

```bash
dnf -y install make
make preqs
make k8-master
```

## Worker Node build

```bash
dnf -y install make
make preqs
# then copy /run the command from the master node /root/worker_join.sh
```

## Prereq Commands
- system-update
- disable-selinux
- kernel-modules
- firewall-rules
- system-rules
- restart-system-rules
- swap-off
- docker-repo-add
- docker-install
- docker-start
- docker-enable
- docker-restart
- docker-cgroups
- kuberneties-repo-add
- kuberneties-bin-install
- containerd-config-update
- containerd-restart
- kubelet-enable
- kubelet-start
- preqs: system-update disable-selinux kernel-modules firewall-rules system-rules \
       restart-system-rules swap-off docker-repo-add docker-install docker-cgroups \
	   containerd-config-update containerd-restart \
	   docker-start docker-enable  kuberneties-repo-add kuberneties-bin-install \
	    kubelet-enable 


## Master Node Commands
- k8-master-pull-images
- k8-master-firewall-rules
- k8-master-config
- k8-master-init
- user-config
- calico
- k8-master:  k8-master-firewall-rules k8-master-pull-images  k8-master-config k8-master-init user-config calico
- taint-master
- worker-cmd

## Worker Node Commands
- firewall-worker

## General Commands
- reset
- get-nodes
- info
