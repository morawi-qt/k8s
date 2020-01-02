#!/bin/bash

packagesSetup() {
  echo "installing packages"
  for server in $host1 $host2 $host3; do
OUTPUT=$(
    ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get update && sudo apt-get install -y apt-transport-https curl' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'curl -q0 -L https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo sh -c "echo 'deb https://apt.kubernetes.io/ kubernetes-xenial main' > /etc/apt/sources.list.d/kubernetes.list"' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get update' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get install -y kubelet=1.12.3-00 kubectl=1.12.3-00' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get install kubeadm=1.12.3-00' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-mark hold kubelet kubeadm kubectl' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get remove -y docker docker-engine docker.io' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'curl -q0 -L https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu' \
    && ssh -i ~/bootstrap.pem ubuntu@$server "echo $server | sudo tee /etc/hostname" \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo rm /etc/resolv.conf && sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf' \
    && ssh -i ~/bootstrap.pem ubuntu@$server 'sudo init 6'
)
packageInstallation=$?
echo "rebooting $server"
sleep 10
echo "$OUTPUT" > "$server"_setup.txt
echo "PACKAGE INSTALLATION EXIT CODE: $packageInstallation" >> "$server"_setup.txt
done
}

createBaseFile() {
  read -r -d '' KUBEADMCONF << _EOF_
apiVersion: kubeadm.k8s.io/v1alpha3
#clusterName: $clusterName
kind: ClusterConfiguration
etcd:
  local:
    extraArgs:
      name: "FQDN"
      listen-client-urls: "https://127.0.0.1:2379,https://IP:2379"
      advertise-client-urls: "https://IP:2379"
      listen-peer-urls: "https://IP:2380"
      initial-advertise-peer-urls: "https://IP:2380"
      initial-cluster: "FQDN=https://IP:2380"
      #initial-cluster-state: existing
    serverCertSANs:
      - FQDN
      - IP
    peerCertSANs:
      - FQDN
      - IP
networking:
    podSubnet: "192.168.0.0/16"
kubernetesVersion: "v1.12.3"
apiServerExtraArgs:
  cloud-provider: aws
controllerManagerExtraArgs:
  cloud-provider: aws
apiServerCertSANs:
- "$lb"
controlPlaneEndpoint: "$lb:6443"
nodeRegistration:
  name: "FQDN"
  kubeletExtraArgs:
    cloud-provider: aws
#NEWHEADER
_EOF_

echo "$KUBEADMCONF" > base_kubeadmconf.txt

}

createFirstFile() {
  echo "creating first file"
  ip=$(getent hosts $host1 | awk '{print $1}')
  fqdn=$(getent hosts $host1 | awk '{print $2}')
  sed "s/FQDN/$fqdn/g" base_kubeadmconf.txt > "$host1"_kubeadm.yaml
  sed "s/IP/$ip/g" -i "$host1"_kubeadm.yaml
}

createRestOfFiles() {
    echo "creating rest of files"
    new_header="---\napiVersion: kubeadm.k8s.io/v1alpha3\nkind: InitConfiguration"
    ip=$(getent hosts $host2 | awk '{print $1}')
    fqdn=$(getent hosts $host2 | awk '{print $2}')
    sed "s/FQDN/$fqdn/g" base_kubeadmconf.txt > "$host2"_kubeadm.yaml
    sed "s/IP/$ip/g" -i "$host2"_kubeadm.yaml
    sed "s/#initial-/initial-/g" -i "$host2"_kubeadm.yaml
    sed "s|#NEWHEADER|${new_header}|g" -i "$host2"_kubeadm.yaml
    newstr=`grep initial-cluster: "$host1"_kubeadm.yaml | sed 's/.$//'`
    newstr+=",$fqdn=https://$ip:2380\""
    str=$newstr
    sed 's#.*initial-cluster:.*#'"$str"'#' -i "$host2"_kubeadm.yaml

    ip=$(getent hosts $host3 | awk '{print $1}')
    fqdn=$(getent hosts $host3 | awk '{print $2}')
    sed "s/FQDN/$fqdn/g" base_kubeadmconf.txt > "$host3"_kubeadm.yaml
    sed "s/IP/$ip/g" -i "$host3"_kubeadm.yaml
    sed "s/#initial-/initial-/g" -i "$host3"_kubeadm.yaml
    sed "s|#NEWHEADER|${new_header}|g" -i "$host3"_kubeadm.yaml
    newstr=`grep initial-cluster: "$host2"_kubeadm.yaml | sed 's/.$//'`
    newstr+=",$fqdn=https://$ip:2380\""
    str=$newstr
    sed 's#.*initial-cluster:.*#'"$str"'#' -i "$host3"_kubeadm.yaml
}

prepareFiles() {
  createBaseFile
  createFirstFile
  createRestOfFiles
}

copyFiles() {
  echo "copying files"
  for node in $host1 $host2 $host3; do
    scp -i bootstrap.pem "$node"_kubeadm.yaml ubuntu@$node:/home/ubuntu
    ssh -i bootstrap.pem ubuntu@$node sudo mv "$node"_kubeadm.yaml /root/
  done
}

setupFirstNode() {
  echo "setting up first node"
    worked=1
    while [ $worked -ne 0 ]; do
      sleep 5
      worked=$(ssh -i bootstrap.pem ubuntu@$currentServer "hostname && nslookup www.google.com" | echo $?)
      echo "setup first node looping once"
    done

  ssh -i bootstrap.pem ubuntu@$host1 "echo 'KUBELET_EXTRA_ARGS=--cloud-provider=aws' | sudo tee /etc/default/kubelet"
  ssh -i bootstrap.pem ubuntu@$host1 sudo kubeadm init --config /root/"$host1"_kubeadm.yaml &> "$host1"_k8s_setup.txt
  ssh -i bootstrap.pem ubuntu@$host1 sudo mkdir -p /root/.kube
  ssh -i bootstrap.pem ubuntu@$host1 sudo cp /etc/kubernetes/admin.conf /root/.kube/config
}

clopyCerts() {
  echo "getting certs"
  ssh -i bootstrap.pem ubuntu@$host1 sudo tar -cf certs.tar /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/ca.key /etc/kubernetes/pki/sa.key /etc/kubernetes/pki/sa.pub /etc/kubernetes/pki/front-proxy-ca.crt /etc/kubernetes/pki/front-proxy-ca.key /etc/kubernetes/pki/etcd/ca.crt /etc/kubernetes/pki/etcd/ca.key /etc/kubernetes/admin.conf
  scp -i bootstrap.pem ubuntu@$host1:/home/ubuntu/certs.tar .
}

distributeCerts() {
  echo "distributing certs"
  for node in $host2 $host3; do
    scp -i bootstrap.pem certs.tar ubuntu@$node:/home/ubuntu
    ssh -i bootstrap.pem ubuntu@$node sudo mv /home/ubuntu/certs.tar /
    ssh -i bootstrap.pem ubuntu@$node "cd / && sudo tar -xf certs.tar"
  done
}

setupOtherNodes() {
  echo "SETTING UP OTHER NODES"
  export host1IP=$(getent hosts $host1 | awk '{print $1}')
  export thirdHostIP=$(getent hosts $host3 | awk '{print $1}')
  for currentServer in $host2 $host3; do

    worked=1
    while [ $worked -ne 0 ]; do
      sleep 5
      worked=$(ssh -i bootstrap.pem ubuntu@$currentServer "kubectl get no" | echo $?)
      echo "setup other nodes looping once"
    done

    export currentServerIP=$(getent hosts $currentServer | awk '{print $1}')
# ftiaxnei ta certs :
# sudo kubeadm alpha phase certs all --config /root/"$currentServer"_kubeadm.yaml \
#
# grafei to /var/lib/kubelet/config.yaml (to yaml configuration tou kubelet - to kubelet ginetai point me vash thn parametro --config) \
# sudo kubeadm alpha phase kubelet config write-to-disk --config /root/"$currentServer"_kubeadm.yaml \
# sudo kubeadm alpha phase kubelet write-env-file --config /root/"$currentServer"_kubeadm.yaml \
#
#
# grafei to /var/lib/kubelet/kubeadm-flags.env, exei thn metavlhth KUBELET_KUBEADM_ARGS (ayth h metavlhth ginetai source sto systemd manifest gia to kubelet service)
#
#       #cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
#       # Note: This dropin only works with kubeadm and kubelet v1.11+
#       [Service]
#       Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
#       Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
#       # This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
#       EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
#       # This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
#       # the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
#       EnvironmentFile=-/etc/default/kubelet
#       ExecStart=
#       ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
#
# sudo kubeadm alpha phase kubeconfig kubelet --config /root/"$currentServer"_kubeadm.yaml \
#
#grafei to /etc/kubernetes/kubelet.conf -- einai ena arxeio pou leei ta endpoints gia to cluster, kai ta pistopoihtika, kathos kai gia ton local server
#
# o kubeadm gia kapoio logo malakizetai kai den vazei to aws sta KUBELET_EXTRA_ARGS
# opote tha to kanoume xeirokinhta: \
# sudo echo "KUBELET_EXTRA_ARGS=--cloud-provider=aws" > /etc/default/kubelet \


#grafei ta: /etc/kubernetes/admin.conf, /etc/kubernetes/kubelet.conf, /etc/kubernetes/controller-manager.conf, /etc/kubernetes/scheduler.conf  -- ** ypotithetai oti einai exypno
#kai mono allazei ta arxeia pou xrhzoun allaghs, h den yparxoun ktl -- metafrash: yparxei megalh periptosh na paei na kanei kamia malakia....
#sudo kubeadm alpha phase kubeconfig all --config /root/"$currentServer"_kubeadm.yaml \

# ftiaxnei ta static pod manifests gia to control plane: /etc/kubernetes/manifests/kube-apiserver.yaml, /etc/kubernetes/manifests/kube-controller-manager.yaml
# kai /etc/kubernetes/manifests/kube-scheduler.yaml
#
# to shmantiko einai o api server kai o controller manager na exoun: --cloud-provider=aws san parametro sto command line tous
# \
# sudo kubeadm alpha phase controlplane all --config /root/"$currentServer"_kubeadm.yaml \
   OUTPUT=$(ssh -i ~/bootstrap.pem ubuntu@$currentServer << END
sudo kubeadm alpha phase certs all --config /root/"$currentServer"_kubeadm.yaml \
&& sudo kubeadm alpha phase kubelet config write-to-disk --config /root/"$currentServer"_kubeadm.yaml \
&& sudo kubeadm alpha phase kubelet write-env-file --config /root/"$currentServer"_kubeadm.yaml \
&& sudo kubeadm alpha phase kubeconfig kubelet --config /root/"$currentServer"_kubeadm.yaml \
&& echo 'KUBELET_EXTRA_ARGS=--cloud-provider=aws' | sudo tee /etc/default/kubelet \
&& sudo systemctl start kubelet
END
)
echo "1st status code: $?"
echo "$OUTPUT" > "$host2"_k8s_setup.txt

    OUTPUT=$(ssh -i ~/bootstrap.pem ubuntu@$currentServer << END
sudo kubeadm alpha phase etcd local --config /root/"$currentServer"_kubeadm.yaml \
&& sudo mkdir -p /root/.kube \
&& sudo cp /etc/kubernetes/admin.conf /root/.kube/config
END
)
echo "2nd status code: $?"
echo "$OUTPUT" >> "$host2"_k8s_setup.txt

status=1; while [ $status -ne 0 ] ; do
    OUTPUT=$(ssh -t -i ~/bootstrap.pem ubuntu@$currentServer sudo -i kubectl exec -n kube-system etcd-${host1} -- etcdctl --ca-file /etc/kubernetes/pki/etcd/ca.crt --cert-file /etc/kubernetes/pki/etcd/peer.crt --key-file /etc/kubernetes/pki/etcd/peer.key --endpoints=https://${host1IP}:2379 member add ${currentServer} https://${currentServerIP}:2380
)
status=$?
sleep 10
echo "kubectl wasn't successful, looping"
done
  echo "3rd status code: $?"
  echo "$OUTPUT" >> "$host2"_k8s_setup.txt

    OUTPUT=$(ssh -i ~/bootstrap.pem ubuntu@$currentServer sudo kubeadm alpha phase kubeconfig all --config /root/"$currentServer"_kubeadm.yaml )
  echo "4th status code: $?"
  echo "$OUTPUT" >> "$host2"_k8s_setup.txt

    OUTPUT=$(ssh -i ~/bootstrap.pem ubuntu@$currentServer << END
sudo kubeadm alpha phase controlplane all --config /root/"$currentServer"_kubeadm.yaml \
&& sudo kubeadm alpha phase kubelet config annotate-cri --config /root/"$currentServer"_kubeadm.yaml \
&& sudo kubeadm alpha phase mark-master --config /root/"$currentServer"_kubeadm.yaml \
&& echo "status code: $?"
END
)
  echo "5th status code: $?"
  echo "$OUTPUT" >> "$host2"_k8s_setup.txt

done

}


remindAboutTags() {
  echo "did you remember:"
  echo "- to set up a LB?"
  echo "- to apply the master/slave IAM policies?"
  echo "- to add the \"kubernetes.io/cluster/kubernetes\" tag on the SG, nodes, subnets and routing tables?"
  echo "- to authorize the etcd servers to join the etcd cluster? (kubectl exec ston etcd master 1)"
  echo "- to create the default storage class? kubectl apply -f https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/storage-class/aws/default.yaml"
  echo "- to set up the slave for the aws cloud provider? (possibly the masters too)"
  echo "- to fix the slave resolv.conf?"
}

if [ -z $0 ]; then
  echo "Usage: ./install_k8s.sh host1 host2 host3 lb"
fi

export clusterName=$1
export host1=$2
export host2=$3
export host3=$4
export lb=$5

echo "s0: $0 , $1 , $2 , $3, $4, $5"

prepareFiles
copyFiles
packagesSetup
setupFirstNode
clopyCerts
distributeCerts
setupOtherNodes
remindAboutTags
