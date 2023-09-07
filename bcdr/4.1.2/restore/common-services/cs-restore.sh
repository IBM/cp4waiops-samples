#!/bin/bash

# © Copyright IBM Corp. 2020, 2022

echo "[INFO] $(date) ############## Common services restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/prereq-check.sh
source $WORKDIR/common/common-utils.sh


namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

#Reading couchdb restore info from config file
csRestoreNamePrefix="cs-restore"
csRestoreLabel="bedrock.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, csRestoreNamePrefix: $csRestoreNamePrefix, csRestoreLabel: $csRestoreLabel"

echo "[WARNING] $(date) Deleting old restored resources if exist"
oc delete -f $WORKDIR/restore/common-services/mongo-restore-dbdump.yaml -n $namespace 2> /dev/null
oc delete po dummy-db -n $namespace 2> /dev/null
oc delete pvc my-mongodump -n $namespace 2> /dev/null
oc delete cm cs-bcdr-config -n $namespace 2> /dev/null

echo "[INFO] $(date) Performing velero restore for common services"
performVeleroRestore $csRestoreNamePrefix $backupName $namespace $csRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/common-services/cs-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "my-mongodump"
pvcCheckReturnValue=$?
if [ $pvcCheckReturnValue -ne 0 ]; then
    echo "[ERROR] $(date) PVC check has failed with return value $pvcCheckReturnValue"
    $WORKDIR/restore/common-services/cs-post-restore.sh
    exit 1
fi

echo "[INFO] $(date) Delete dummy-pod since it's work is to only pull data into pvc"
oc delete po dummy-db -n $namespace

echo "[INFO] $(date) Deleting .velero directory from /dump location"
oc create -f $WORKDIR/restore/common-services/cleanup-pod.yaml -n $namespace
checkResourceReadyness "$namespace" "app=cleanup-pod" "40" "pod"
oc delete po cleanup-pod -n $namespace

# Setting mongo dump image value in restore job
mongodb_dump_image=$(oc get cm cs-bcdr-config -n ibm-common-services -o jsonpath='{.data.mongoDumpImage}')
sed -i "s~MONGODB_DUMP_IMAGE~$mongodb_dump_image~g" $WORKDIR/restore/common-services/mongo-restore-dbdump.yaml

echo "[INFO] $(date) Running mongo restore job"
oc create -f $WORKDIR/restore/common-services/mongo-restore-dbdump.yaml -n $namespace
oc get job icp-mongodb-restore -n $namespace
op=$(echo $?)
 
if [[ "$op" -eq 0 ]]; then
   echo "[INFO] $(date) ICP mongodb restore job created"
else
   echo "[ERROR] $(date) ICP mongodb restore job not created hence not executing further restore steps"
   $WORKDIR/restore/common-services/cs-post-restore.sh
   exit 1
fi

waitTillJobCompletion "icp-mongodb-restore" $namespace

$WORKDIR/restore/common-services/cs-post-restore.sh

echo "[INFO] $(date) ############## Common services restore completed ##############"
