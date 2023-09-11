#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#
echo "[INFO] $(date) ############## CAM restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

camRestoreNamePrefix="cam-restore"
camRestoreLabel="cam.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, camRestoreNamePrefix: $camRestoreNamePrefix,  camRestoreLabel: $camRestoreLabel"

echo "[INFO] $(date) Executing cam pre restore tasks"
$WORKDIR/restore/cam/cam-pre-restore.sh

echo "[INFO] $(date) Performing velero restore for cam"
performVeleroRestore $camRestoreNamePrefix $backupName $namespace $camRestoreLabel
restoreRetVal=$?
echo "Velero restore return value is $restoreRetVal"
if [ $restoreRetVal -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/cam/cam-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "cam-mongo-pv"

echo "[INFO] $(date) Executing cam post restore tasks"
$WORKDIR/restore/cam/cam-post-restore.sh

# Wait till cam-mongo pod is ready
checkPodReadyness $namespace "name=cam-mongo" "60"

echo "[INFO] $(date) ############## CAM restore completed ##############"
