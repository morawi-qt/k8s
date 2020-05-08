 
 #!/bin/bash
  
sudo apt-get remove Jenkins
sudo apt-get remove --auto-remove jenkins
sudo apt-get remove --purge jenkins

# The latter will have to be tackled manually this removing to storage for future reference.
sudo mv /usr/share/jenkins/ /opt/jenkins/usr-share-jenkins

exit 0
          
 
 
