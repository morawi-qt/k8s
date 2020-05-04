#!/bin/bash

# The initial command is like this
## 
kubeadm join 10.6.1.20:6443 --token puiuf1.jyh25thq1m667j23 \
    --discovery-token-ca-cert-hash sha256:c49a17ef413465102b8b40a1dd0d4b2e74f3f998d94e3fd64b65a389a34cb730 ##

Generate the control-plane-certificate
sudo kubeadm init phase upload-certs --upload-certs --v=5

#Final command on a 2nd or 3rd controller

# sudo kubeadm join internal-K8S-2020-A-Controller-6443-LB-1159900361.eu-west-2.elb.amazonaws.com:6443 --token puiuf1.jyh25thq1m667j23  --discovery-token-ca-cert-hash sha256:c49a17ef413465102b8b40a1dd0d4b2e74f3f998d94e3fd64b65a389a34cb730  --control-plane --certificate-key e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 --v=5
