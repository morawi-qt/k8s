#!/bin/bash

systemctl daemon-reload
systemctl enable etcd
systemctl start etcd
etcdctl cluster-health



#clean kube after each itteration in the script

mv /etc/default/etcd{,bk}
mv /var/lib/etcd/default /opt/default-01
mv /etc/kubernetes/manifests/kube-apiserver.yaml /opt
mv /etc/kubernetes/manifests/kube-scheduler.yaml /opt
mv /etc/kubernetes/manifests/kube-controller-manager.yaml /opt
mv /etc/kubernetes/manifests/etcd.yaml /opt
mv /var/lib/etcd/member /opt

#  the docker part

systemctl daemon-reload
systemctl restart docker


# Install the Nodes (K8S && DOCKER):

kubeadm init --config=local-access-No-DNS-k8s-2020-b-eu-west-01-controller-01.yaml --v=5
