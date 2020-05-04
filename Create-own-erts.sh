#!/bin/bash


# Install tools needed for certs to be generated


curl -o /usr/local/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -o /usr/local/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x /usr/local/bin/cfssl*


# Create or install certs

sudo mkdir /opt/certificates
cat > /opt/certificates/ca-config.json <<EOF

{
    "signing":
    {
        "default": {
        "expiry": "87600h"
        },
        "profiles": {
        "kubernetes": {
            "usages": [
                "signing",
                "key encipherment",
                "server auth",
                "client auth"
            ],
            "expiry": "87600h"
        }
        }
    }
}

EOF

cat > /opt/certificates/ca-csr.json <<EOF


    {
        "CN": "quant.network",
        "key": {
            "algo": "rsa",
            "size": 2048
        },
        "names": [
            {
            "C": "UK",
            "ST": "ENGLAND",
            "L": "LONDON",
            "O": "QUANT",
            "OU": "Devops"
            }
        ]
    }

EOF

cat > /opt/certificates/etcd-csr.json <<EOF
{
    "CN": "etcd",
    "hosts": [
            "127.0.0.1",
            "10.6.1.20",
            "10.6.1.22",
            "10.6.1.24"
        ],
        "key": {
            "algo": "rsa",
            "size": 2048
        },
        "names": [
            {
            "C": "UK",
            "ST": "ENGLAND",
            "L": "LONDON",
            "O": "QUANT",
            "OU": "Devops"
            }
        ]
    }

EOF


# Move certs to targets(Other nodes):




scp -pr /etc/kubernetes/pki/ca.crt 10.6.1.22:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/ca.crt 10.6.1.24:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/ca.key 10.6.1.22:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/ca.key 10.6.1.24:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/sa.key 10.6.1.22:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/sa.key 10.6.1.24:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/sa.pub 10.6.1.22:/etc/kubernetes/pki
scp -pr /etc/kubernetes/pki/sa.pub 10.6.1.24:/etc/kubernetes/pki

