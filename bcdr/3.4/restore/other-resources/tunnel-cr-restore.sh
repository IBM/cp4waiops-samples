#!/bin/bash

#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================

source ../restore-utils.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
backupName=$(cat ../restore-data.json | jq -r '.backupName')
tunnelRestoreNamePrefix="tunnel-restore"
tunnelRestoreLabel="otherresources.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $tunnelRestoreNamePrefix $tunnelRestoreLabel

# Performing velero restore for tunnel
performVeleroRestore $tunnelRestoreNamePrefix $backupName $namespace $tunnelRestoreLabel

# Move the tunnel-restore.sh script outside of backup-other-resources pod and execute it
{  # try
   oc cp -n $namespace backup-other-resources:/usr/share/backup/tunnel-restore.sh /tmp/tunnel-restore.sh &&
   echo "tunnel-restore.sh file transferred to outside of backup-other-resources pod"
   chmod +x /tmp/tunnel-restore.sh
   # Executing tunnel-restore.sh script
   /tmp/tunnel-restore.sh -n $namespace

} || { # catch
   echo "tunnel-restore.sh script transfer or execution failed, hence exiting!"
   exit 1
}

oc delete pod backup-other-resources -n $namespace
oc delete pvc other-resources-backup-data -n $namespace

echo "Tunnel restore is completed"

