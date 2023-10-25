#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

echo "[WARNING] $(date) Deleting previously restored cassandra resources if exist"
oc delete pod -n $namespace -l cassandra.cp4aiops.ibm.com/backup=t 2> /dev/null
oc delete cm cassandra-bcdr-config -n $namespace 2> /dev/null

echo "[INFO] $(date) Getting the replica count for sts aiops-topology-cassandra before scaling down the required pods"
CASSANDRA_RC=$(oc get sts aiops-topology-cassandra -n $namespace -o=jsonpath='{.spec.replicas}')
echo "[INFO] $(date) Before scaling down aiops-topology-cassandra statefulset replica count is $CASSANDRA_RC"

#Saving the replica count values to a json file as it's required for post-restore script
JSON='{"CASSANDRA_RC": '"$CASSANDRA_RC"'}'
rm -f $WORKDIR/restore/cassandra/cassandra-rc-data.json
echo $JSON > $WORKDIR/restore/cassandra/cassandra-rc-data.json

echo "[WARNING] $(date) Scaling down the aiops-topology-cassandra sts"
oc scale sts aiops-topology-cassandra -n $namespace --replicas=0

echo "[WARNING] $(date) Deleting all back-aiops-topology-cassandra pvc's"
pvcList=$(oc get pvc -n $namespace | grep back-aiops-topology-cassandra- | cut -d " " -f1)
for pvc in $pvcList; do
    echo "[INFO] $(date) PVC name is $pvc"
    oc delete pvc -n $namespace $pvc
done
