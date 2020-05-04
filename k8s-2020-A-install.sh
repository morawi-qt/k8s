
#!/bin/bash 
# Install essential components  
sudo apt-get -y update && upgrade
sudo -y apt-get install curl wget ipvsadm
sudo mkdir -p /etc/systemd/system/docker.service.d/ && printf "[Service]\nExecStartPost=/sbin/iptables -P FORWARD ACCEPT" | sudo tee /etc/systemd/system/docker.service.d/10-iptables.conf
sudo hostnamectl set-hostname ip-10-6-1-20.eu-west-2.compute.internal
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl --system
sudo swapoff -a

# Set SELinux in permissive mode (effectively disabling it)
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sudo systemctl disable firewalld --now # Disable the firewall
# Turn off the swap: Required for Kubernetes to work
sudo swapoff -a

#Docker install begins
sudo apt -y  remove docker docker-engine docker.io
sudo apt -y install apt-transport-https ca-certificates curl software-properties-common gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt -y update
sudo apt -y install docker-ce
# get ubuntu user to be docker controller
sudo usermod -aG docker $USER
sudo systemctl enable docker


sudo cat <<EOT >> /etc/docker/daemon.json





{

"exec-opts": ["native.cgroupdriver=systemd"],

"log-driver": "json-file",

"log-opts": {

"max-size": "100m"

},

"storage-driver": "overlay2",
"insecure-registries": ["10.7.1.26:8122"]

}

EOT

mkdir /home/ubuntu/.docker
cat <<END >> /home/ubuntu/.docker/config.json


{
        "auths": {
                "10.7.1.26:8122": {
                        "auth": "YWRtaW46YWRtaW4xMjM="
                }

        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.8 (linux)"
        }
}




END

#K8S install begins
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-add-repository 'deb http://apt.kubernetes.io/ kubernetes-xenial main'
sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl


exit 0
