#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================

source ../restore-utils.sh
source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

minioRestoreNamePrefix="minio-restore"
minioRestoreLabel="minio.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $minioRestoreNamePrefix $minioRestoreLabel

# Executing minio pre restore tasks
./minio-pre-restore.sh

# Performing velero restore for minio
performVeleroRestore $minioRestoreNamePrefix $backupName $namespace $minioRestoreLabel

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "export-aimanager-ibm-minio-"

# Executing minio post restore tasks
./minio-post-restore.sh

# Wait till minio pods are ready
checkPodReadyness $namespace "app.kubernetes.io/name=ibm-minio" "60"

echo "Minio restore is completed"