#!/bin/bash
echo "[INFO] $(date) ############## Starting Elasticsearch pre-restore ##############"

source ../../common/common-utils.sh
source ../restore-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
esRestoreNamePrefix="es-restore"
backupName=$(cat ../restore-data.json | jq -r '.backupName')
esRestoreLabel="elasticsearch.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, esRestoreNamePrefix: $esRestoreNamePrefix,  esRestoreLabel: $esRestoreLabel"

echo "[INFO] $(date) Removing previously registered backup path from automationbase CR if exists"
INDEX=$(oc get automationbase automationbase-sample -n $namespace -o json  | jq '.spec.elasticsearch.nodegroupspecs[0].config | map(.value == "/usr/share/elasticsearch/snapshots/es-backup") | index(true)')
echo "[INFO] $(date) Backup path index is $INDEX, if the index value is null then backup path is not registered"
oc patch --type=json automationbase automationbase-sample -n $namespace -p="[{ 'op': 'remove','path': '/spec/elasticsearch/nodegroupspecs/0/config/$INDEX'}]" 2> /dev/null

echo "[INFO] $(date) Removing previously registered snapshot location from automationbase CR if exists"
oc patch --type=json automationbase automationbase-sample -n $namespace -p="[{ 'op': 'remove','path': '/spec/elasticsearch/snapshotStores'}]" 2> /dev/null

echo "[INFO] $(date) Deleting ElasticSearch backup snapshot PVC and pod if exists"
oc delete pod es-backup -n $namespace 2> /dev/null
oc delete pvc -n $namespace iaf-system-elasticsearch-es-snap-es-backup-pvc 2> /dev/null
oc delete cm es-bcdr-config -n $namespace 2> /dev/null

echo "[INFO] $(date) Waiting till all elasticsearch pods are READY after updating backup path and snapshot location in automationbase CR"
wait "60"
checkPodReadynessV2 $namespace "app.kubernetes.io/name=elasticsearch" "60"
echo "Pod Readyness check return value is $podReadynessCheckValue"
if [ $podReadynessCheckValue -ne 0 ]; then
      echo "[ERROR] $(date) Pod Readyness check failed, hence exiting"
      exit 1
fi

echo "[INFO] $(date) Performing velero restore for ElasticSearch"
performVeleroRestore $esRestoreNamePrefix $backupName $namespace $esRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence exiting"
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "iaf-system-elasticsearch-es-snap-es-backup-pvc"

echo "[INFO] $(date) es-velero-restore script execution completed"
