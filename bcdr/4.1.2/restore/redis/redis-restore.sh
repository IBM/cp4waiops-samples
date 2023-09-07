#!/bin/bash

# © Copyright IBM Corp. 2020, 2022
echo "[INFO] $(date) ############## Redis restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

redisRestoreNamePrefix="redis-restore"
redisRestoreLabel="redis.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, redisRestoreNamePrefix: $redisRestoreNamePrefix, redisoRestoreLabel: $redisRestoreLabel"

echo "[INFO] $(date) Executing redis pre restore tasks"
$WORKDIR/restore/redis/redis-pre-restore.sh

echo "[INFO] $(date) Performing velero restore for redis"
performVeleroRestore $redisRestoreNamePrefix $backupName $namespace $redisRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/redis/redis-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "data-c-example-redis-m-"

echo "[INFO] $(date) Executing redis post restore tasks"
$WORKDIR/restore/redis/redis-post-restore.sh

# Wait till redis pods are ready
checkPodReadynessV2 $namespace "formation_type=redis" "60"

echo "[INFO] $(date) ############## Redis restore completed ##############"