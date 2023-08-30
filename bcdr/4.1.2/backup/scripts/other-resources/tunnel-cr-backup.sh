#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#
echo "[INFO] $(date) ############## Tunnel CR backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/common-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

tunnelCRBackup="false"

# Taking backup of tunnel CR's
$WORKDIR/backup/scripts/other-resources/ibm-tunnel-backup.sh -n $namespace -f /tmp/tunnel-restore.sh

if [ $? -eq 0 ]; then
   echo "[INFO] $(date) Tunnel backup script execution succeeded"

else
   echo "[ERROR] $(date) Tunnel backup script execution failed, hence exiting!"
   exit 1
fi

# Move the tunnel-restore.sh script to backup-other-resources pod
{  # try
   oc cp -n $namespace /tmp/tunnel-restore.sh backup-other-resources:/usr/share/backup/tunnel-restore.sh &&
   echo "[INFO] $(date) tunnel-restore.sh file to backup-other-resources pod transferred!" &&
   tunnelCRBackup="true"
} || { # catch
   echo "[ERROR] $(date) Transfer of tunnel-restore.sh file to backup-other-resources pod failed, hence exiting!"
   echo "[WARNING] $(date) Deleting backup-other-resources pod and pvc"
   oc delete -f other-resources-backup.yaml -n $namespace
   exit 1
}

# Updating the backup result for IBM tunnel CR
if [[ $tunnelCRBackup == "true" ]]; then
   jq '.tunnelCRBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

echo "[INFO] $(date) ############## Tunnel CR backup completed ##############"
