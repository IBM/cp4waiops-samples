#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================

echo "[INFO] $(date) ############## Couchdb restore started ##############"

source ../restore-utils.sh
source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

#Reading couchdb restore info from config file
couchDbRestoreNamePrefix="couchdb-restore"
couchDbRestoreLabel="couchdb.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, couchDbRestoreNamePrefix: $couchDbRestoreNamePrefix,  couchDbRestoreLabel: $couchDbRestoreLabel"

echo "[INFO] $(date) Executing couchdb pre restore tasks"
./couchdb-pre-restore.sh

echo "[INFO] $(date) Performing velero restore for couchdb"
performVeleroRestore $couchDbRestoreNamePrefix $backupName $namespace $couchDbRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      ./couchdb-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "data-c-example-couchdbcluster-m-"

echo "[INFO] $(date) Executing couchdb post restore tasks"
./couchdb-post-restore.sh

# Wait till couchdb and rba pods are ready
checkPodReadyness $namespace "app.kubernetes.io/component=rba-as" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=rba-rbs" "60"
#checkPodReadyness $namespace "app.kubernetes.io/instance=example-couchdbcluster" "60"

echo "[INFO] $(date) ############## Couchdb restore completed ##############"
