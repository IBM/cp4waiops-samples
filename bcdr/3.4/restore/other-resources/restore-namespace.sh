#!/bin/bash

source ../restore-utils.sh

backupName=$(cat ../restore-data.json | jq -r '.backupName')
aiopsNamespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
csNamespace=$(cat ../../common/aiops-config.json | jq -r '.csNamespace')

echo "Restoring $csNamespace and $aiopsNamespace namespaces"
csNamespaceRestoreName="cs-namespace-restore-"$(date '+%Y%m%d%H%M%S')
aiopsNamespaceRestoreName="aiops-namespace-restore-"$(date '+%Y%m%d%H%M%S')

echo "Restoring the $csNamespace namespace"
velero restore create $csNamespaceRestoreName --from-backup $backupName -l kubernetes.io/metadata.name=$csNamespace
waitTillRestoreCompletion "$csNamespaceRestoreName"

echo "Restoring the $aiopsNamespace namespace"
velero restore create $aiopsNamespaceRestoreName --from-backup $backupName -l kubernetes.io/metadata.name=$aiopsNamespace
waitTillRestoreCompletion "$aiopsNamespaceRestoreName"

echo "Removing the  redis.databases.cloud.ibm.com/account-hash annotation from $aiopsNamespace namespace"
oc annotate namespace $aiopsNamespace redis.databases.cloud.ibm.com/account-hash-

echo "Namespace restore is completed"