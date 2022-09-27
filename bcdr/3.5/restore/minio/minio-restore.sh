#!/bin/bash

#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================
echo "[INFO] $(date) ############## Minio restore started ##############"

source ../restore-utils.sh
source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

minioRestoreNamePrefix="minio-restore"
minioRestoreLabel="minio.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, minioRestoreNamePrefix: $minioRestoreNamePrefix, minioRestoreLabel: $minioRestoreLabel"

echo "[INFO] $(date) Executing minio pre restore tasks"
./minio-pre-restore.sh

echo "[INFO] $(date) Performing velero restore for minio"
performVeleroRestore $minioRestoreNamePrefix $backupName $namespace $minioRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      ./minio-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "export-aimanager-ibm-minio-"

echo "[INFO] $(date) Executing minio post restore tasks"
./minio-post-restore.sh

# Wait till minio pods are ready
checkPodReadyness $namespace "app.kubernetes.io/name=ibm-minio" "60"

echo "[INFO] $(date) ############## Minio restore completed ##############"
