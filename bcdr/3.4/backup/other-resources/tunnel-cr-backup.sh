#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source ../../common/common-utils.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

# Taking backup of tunnel CR's
./ibm-tunnel-backup.sh -n $namespace -f /tmp/tunnel-restore.sh

if [ $? -eq 0 ]; then
   echo "Tunnel backup script execution succeeded"

else
   echo "Tunnel backup script execution failed, hence exiting!"
   exit 1
fi

# Move the tunnel-restore.sh script to backup-other-resources pod
{  # try
   oc cp -n $namespace /tmp/tunnel-restore.sh backup-other-resources:/usr/share/backup/tunnel-restore.sh &&
   echo "tunnel-restore.sh file to backup-other-resources pod transferred!" 
} || { # catch
   echo "Transfer of tunnel-restore.sh file to backup-other-resources pod failed, hence exiting!"
   echo "Deleting backup-other-resources pod and pvc"
   oc delete -f other-resources-backup.yaml -n $namespace
   exit 1
}