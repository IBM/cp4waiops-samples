#!/bin/bash
echo "[INFO] $(date) ############## Namespace restore started ##############"

source $WORKDIR/restore/restore-utils.sh

backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
aiopsNamespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
csNamespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')

echo "[INFO] $(date) Namespaces to be restored are $csNamespace and $aiopsNamespace"
csNamespaceRestoreName="cs-namespace-restore-"$(date '+%Y%m%d%H%M%S')
aiopsNamespaceRestoreName="aiops-namespace-restore-"$(date '+%Y%m%d%H%M%S')

echo "[INFO] $(date) Restoring the $csNamespace namespace"
velero restore create $csNamespaceRestoreName --from-backup $backupName -l kubernetes.io/metadata.name=$csNamespace
waitTillRestoreCompletion "$csNamespaceRestoreName"

echo "[INFO] $(date) Restoring the $aiopsNamespace namespace"
velero restore create $aiopsNamespaceRestoreName --from-backup $backupName -l kubernetes.io/metadata.name=$aiopsNamespace
waitTillRestoreCompletion "$aiopsNamespaceRestoreName"

echo "[INFO] $(date) Removing the redis.databases.cloud.ibm.com/account-hash annotation from $aiopsNamespace namespace"
oc annotate namespace $aiopsNamespace redis.databases.cloud.ibm.com/account-hash-

echo "[INFO] $(date) ############## Namespace restore completed ##############"
