#!/bin/bash

#*===================================================================
#*
#   IBM Confidential
#   5737-M96
#   (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
#   
#   
#*
#*===================================================================
echo "[INFO] $(date) ############## Minio restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

minioRestoreNamePrefix="minio-restore"
minioRestoreLabel="minio.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, minioRestoreNamePrefix: $minioRestoreNamePrefix, minioRestoreLabel: $minioRestoreLabel"

echo "[INFO] $(date) Executing minio pre restore tasks"
$WORKDIR/restore/minio/minio-pre-restore.sh

echo "[INFO] $(date) Performing velero restore for minio"
performVeleroRestore $minioRestoreNamePrefix $backupName $namespace $minioRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/minio/minio-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "export-aimanager-ibm-minio-"

echo "[INFO] $(date) Executing minio post restore tasks"
$WORKDIR/restore/minio/minio-post-restore.sh

# Wait till minio pods are ready
checkPodReadyness $namespace "app.kubernetes.io/name=ibm-minio" "60"
# Wait till aiops-ir-ui-api-graphql pods are ready
checkPodReadyness $namespace "component=aiops-ir-ui-api-graphql" "60"

# Clearing the all annotation of LifecycleTrigger CR and delete the lifecycle job and task managers to kick start things
echo "[INFO] $(date) Executing command to clear the all annotations from LifecycleTrigger"
oc patch lifecycletrigger aiops  -n $namespace --type=json -p='[{"op": "remove", "path": "/metadata/annotations"}]'
oc delete po -l  cluster=aiops-ir-lifecycle-eventprocessor-ep -n $namespace

echo "[INFO] $(date) ############## Minio restore completed ##############"
