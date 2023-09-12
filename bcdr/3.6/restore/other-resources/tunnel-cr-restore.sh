#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================
echo "[INFO] $(date) ############## Tunnel CR restore started ##############"

source $WORKDIR/restore/restore-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
tunnelRestoreNamePrefix="tunnel-restore"
tunnelRestoreLabel="otherresources.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, tunnelRestoreNamePrefix: $tunnelRestoreNamePrefix, tunnelRestoreLabel: $tunnelRestoreLabel"

echo "[INFO] $(date) Performing velero restore for tunnel cr's"
performVeleroRestore $tunnelRestoreNamePrefix $backupName $namespace $tunnelRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/other-resources/tunnel-cr-post-restore.sh
      exit 1
fi

# Move the tunnel-restore.sh script outside of backup-other-resources pod and execute it
{  # try
   oc cp -n $namespace backup-other-resources:/usr/share/backup/tunnel-restore.sh /tmp/tunnel-restore.sh &&
   echo "[INFO] $(date) tunnel-restore.sh file transferred to outside of backup-other-resources pod"
   chmod +x /tmp/tunnel-restore.sh
   # Executing tunnel-restore.sh script
   /tmp/tunnel-restore.sh -n $namespace

} || { # catch
   echo "[ERROR] $(date) tunnel-restore.sh script transfer or execution failed, hence exiting!"
   $WORKDIR/restore/other-resources/tunnel-cr-post-restore.sh
   exit 1
}

$WORKDIR/restore/other-resources/tunnel-cr-post-restore.sh

echo "[INFO] $(date) ############## Tunnel CR restore completed ##############"
