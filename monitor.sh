#!/bin/bash

#Check docker is in the correct driver

docker info -f "{{.CgroupDriver}}" 

#Encrypt a password for it to be compatible with Docker files:

echo -n 'admin:' | base64

#Check a specific component for a specific time

sudo journalctl -exu docker --since "2 hour ago"

exit 0
