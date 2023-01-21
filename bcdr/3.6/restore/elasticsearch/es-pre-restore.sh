#!/bin/bash
echo "[INFO] $(date) ############## Starting Elasticsearch pre-restore ##############"

source $WORKDIR/common/common-utils.sh
source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/prereq-check.sh

waitTillSnapshotConfigsAreUpdatedInEsPods() {
    namespace=$1
    podLabel=$2
    retryCount=$3
    podList=$(oc -n $namespace get pods -l $podLabel --no-headers=true --output=custom-columns=NAME:.metadata.name)
    if [ -z "$podList" ]; then
      echo -e "[INFO] $(date) pods having label $podLabel are: \n$podList"
      echo -e "[INFO] $(date) No pod found with label $podLabel so terminating the script execution"
      exit 1
    else
      echo -e "[INFO] $(date) pods having label $podLabel are: \n$podList"
    fi

    for pod in $podList; do
        counter=0
        echo "[Debug] $(date) Counter value is $counter"
        esConfigDetailsValue=$(oc get pod $pod -n $namespace -o=jsonpath='{.spec.volumes[?(@.name=="iaf-system-elasticsearch-es-snap-es-backup")]}')
        echo -e "[INFO] $(date) Elasticsearch snapshot configuration details in pod $pod are: \n$esConfigDetailsValue"
        
        while [ -z "$esConfigDetailsValue" ]
        do
          echo "[INFO] $(date) Waiting for 10 sec"
          wait "10"
          ((counter++))
          if [[ $counter -eq $retryCount ]]; then
               echo "[ERROR] $(date) Exiting as pod $pod is not having required snapshot configuration details after waiting maximum time"
               exit 1
               #podReadynessCheckValue=1
               #return $podReadynessCheckValue
          fi
          esConfigDetailsValue=$(oc get pod $pod -n $namespace -o=jsonpath='{.spec.volumes[?(@.name=="iaf-system-elasticsearch-es-snap-es-backup")]}')
          echo -e "[INFO] $(date) Elasticsearch snapshot configuration details in pod $pod are: \n$esConfigDetailsValue"
        done
   done
}

waitTillSnapshotConfigsAreRemovedFromEsPods() {
    namespace=$1
    podLabel=$2
    retryCount=$3
    podList=$(oc -n $namespace get pods -l $podLabel --no-headers=true --output=custom-columns=NAME:.metadata.name)
    if [ -z "$podList" ]; then
      echo -e "[INFO] $(date) pods having label $podLabel are: \n$podList"
      echo -e "[INFO] $(date) No pod found with label $podLabel so terminating the script execution"
      exit 1
    else
      echo -e "[INFO] $(date) pods having label $podLabel are: \n$podList"
    fi

    for pod in $podList; do
        counter=0
        echo "[Debug] $(date) Counter value is $counter"
        esConfigDetailsValue=$(oc get pod $pod -n $namespace -o=jsonpath='{.spec.volumes[?(@.name=="iaf-system-elasticsearch-es-snap-es-backup")]}')
        echo -e "[INFO] $(date) Elasticsearch snapshot configuration details in pod $pod are: \n$esConfigDetailsValue"
        
        while [[ ! -z "$esConfigDetailsValue" ]]
        do
          echo "[INFO] $(date) Waiting for 10 sec"
          wait "10"
          ((counter++))
          if [[ $counter -eq $retryCount ]]; then
               echo "[ERROR] $(date) Exiting as pod $pod is not having required snapshot configuration details after waiting maximum time"
               exit 1
               #podReadynessCheckValue=1
               #return $podReadynessCheckValue
          fi
          esConfigDetailsValue=$(oc get pod $pod -n $namespace -o=jsonpath='{.spec.volumes[?(@.name=="iaf-system-elasticsearch-es-snap-es-backup")]}')
          echo -e "[INFO] $(date) Elasticsearch snapshot configuration details in pod $pod are: \n$esConfigDetailsValue"
        done
   done
}

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
esRestoreNamePrefix="es-restore"
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

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

echo "[INFO] $(date) Waiting till all elasticsearch pods are READY after removing backup path and snapshot location from automationbase CR"
waitTillSnapshotConfigsAreRemovedFromEsPods $namespace "app.kubernetes.io/component=es" "20"
checkPodReadynessV2 $namespace "app.kubernetes.io/name=elasticsearch" "60"

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

echo "[INFO] $(date) Updating backup path and snapshot location in automationbase CR"
$WORKDIR/restore/elasticsearch/automationbase-cr-update.sh

echo "[INFO] $(date) Waiting till all elasticsearch pods are READY after updating backup path and snapshot location in automationbase CR"
waitTillSnapshotConfigsAreUpdatedInEsPods $namespace "app.kubernetes.io/component=es" "20"
checkPodReadynessV2 $namespace "app.kubernetes.io/name=elasticsearch" "60"

echo "[INFO] $(date) Waiting for 2 mins for other pods to be ready"
wait "120"

echo "[INFO] $(date) ############## Elasticsearch pre-restore process completed ##############"
