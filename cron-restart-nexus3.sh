#!/bin/bash
  
normaltestoutput=`ss -tulpn | grep 8080 | awk '{print($5)}' | sed 's/^.\{2\}//'`
correctOutput="8122"
if [ "$normaltestoutput" != "$correctOutput" ];
then

        echo "RESTARTING NEXUS THIS MIGHT have IMPACTED CICD"
        `/usr/bin/sudo /opt/nexus-3.22.0-02/bin/nexus start`

fi

