#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#
echo "[INFO] $(date) ############## Cassandra restore started ##############"

source $WORKDIR/restore/cassandra/cassandra-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh
source $WORKDIR/restore/restore-utils.sh

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
cassandrapodlabel="app=cassandra"
aiopstopologypodlabel="app.kubernetes.io/instance=aiops-topology"
aiopsanalyticspodlabel="app.kubernetes.io/managed-by=aiops-analytics-operator"
aiopsiroperatorpodlabel="app.kubernetes.io/name=ibm-ir-ai-operator"

echo "[INFO] $(date) Running the pre-restore steps for Cassandra before running the Velero restore"
$WORKDIR/restore/cassandra/cassandra-pre-restore.sh

echo "[INFO] $(date) Iniliazing the variable for Cassandra restore using Velero"
cassandraDbRestoreNamePrefix="cassandra-restore"
cassandraDbRestoreLabel="cassandra.cp4aiops.ibm.com/backup=t"

# namespace value is being sourced from cassandra-utils.sh 
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, cassandraDbRestoreNamePrefix: $cassandraDbRestoreNamePrefix, cassandraDbRestoreLabel: $cassandraDbRestoreLabel"
echo "[INFO] $(date) Performing velero restore for Cassandra"
performVeleroRestore $cassandraDbRestoreNamePrefix  $backupName $namespace $cassandraDbRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/cassandra/cassandra-post-restore.sh
      exit 1
fi

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "back-aiops-topology-cassandra-"
pvcCheckReturnValue=$?
if [ $pvcCheckReturnValue -ne 0 ]; then
    echo "[ERROR] $(date) PVC check has failed with return value $pvcCheckReturnValue"
    $WORKDIR/restore/cassandra/cassandra-post-restore.sh
    exit 1
fi

echo "[INFO] $(date) Running the post-restore steps for Cassandra after running the Velero restore"
$WORKDIR/restore/cassandra/cassandra-post-restore.sh

checkPodReadyness $namespace $cassandrapodlabel "90"

#Pre backup task for cassandra native restore operation
echo "[WARNING] $(date) Scaling down the Agile Service Manager pods and running the Cassandra native pre-restore after Velero restore is done"
$WORKDIR/restore/cassandra/cassandra-native-pre-restore.sh
wait "90"

#This will be applicable to only multi node Cassandra cluster
#This will copy the cassandra_function.sh to all Cassandra pods
$WORKDIR/restore/cassandra/cassandra-script-update.sh


#Trigger restore for the Cassandra keyspaces
echo "[INFO] $(date) Triggering the Cassandra native restore now"
$WORKDIR/restore/cassandra/trigger-cassandra-restore.sh

echo "[WARNING] $(date) Deleting cassandra-bcdr-config configmap"
oc delete cm cassandra-bcdr-config -n $namespace 

#Post backup task for cassandra
echo "[INFO] $(date) Scaling up the Agile Service Manager pods and running the Cassandra native post-restore after Cassandra native restore is done"
$WORKDIR/restore/cassandra/cassandra-native-post-restore.sh
#echo "Wait for pods with label $aiopsiroperatorpodlabel to be in ready state"
#checkPodReadyness $namespace $aiopsiroperatorpodlabel "90"
#echo "Wait for pods with label $aiopstopologypodlabel to be in ready state"
#checkPodReadyness $namespace $aiopstopologypodlabel "90"
#echo "Wait for pods with label $aiopsanalyticspodlabel to be in ready state"
#checkPodReadyness $namespace $aiopsanalyticspodlabel "90"
wait "60"

echo "[INFO] $(date) Running patch for IssueResolutionCore"
oc patch IssueResolutionCore aiops --type json -p '[{"op":"add", "path":"/spec/elasticsearch/repair", "value":true}]' -n $namespace
waitTillJobCompletion "aiops-ir-core-ncodl-setup" $namespace

echo "[INFO] $(date) Run node upgrade in pod aiops-ir-lifecycle-policy-registry-svc"
kPodLoop "aiops-ir-lifecycle-policy-registry-svc" "cd /app/lib/tools && /app/entrypoint.sh node upgrade --tenantid \$API_AUTHSCHEME_NOIUSERS_TENANTID"

echo "[INFO] $(date) Rebroadcasting data to ElasticSearch"
kPodLoop "aiops-topology-topology-" "curl -vX POST 'https://localhost:8080/1.0/topology/crawlers/rebroadcast' -H 'X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255' --insecure -u \$ASM_USER:\$ASM_PASS"

echo "[INFO] $(date) ############## Cassandra restore completed ##############"
