#!/bin/bash

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Getting the replica count before scaling down the required pods
COUCHDB_RC=$(oc get sts c-example-couchdbcluster-m -n $namespace -o=jsonpath='{.spec.replicas}')
echo Before scaling down c-example-couchdbcluster-m statefulset replica count is $COUCHDB_RC
RBA_AS_RC=$(oc get deploy aiops-ir-core-rba-as -n $namespace -o=jsonpath='{.spec.replicas}')
echo Before scaling down aiops-ir-core-rba-as deployement replica count is $RBA_AS_RC
RBS_RC=$(oc get deploy aiops-ir-core-rba-rbs -n $namespace -o=jsonpath='{.spec.replicas}')
echo Before scaling down aiops-ir-core-rba-rbs deployement replica count is $RBS_RC

# Deleting previously restored couchdb resources if exist
oc delete po -n $namespace -l couchdb.cp4aiops.ibm.com/backup=t

#Saving the replica count values to a json file as it's required for post-restore script
JSON='{"COUCHDB_RC": '"$COUCHDB_RC"', "RBA_AS_RC": '"$RBA_AS_RC"', "RBS_RC": '"$RBS_RC"'}'
rm -f couchdb-rc-data.json
echo $JSON > couchdb-rc-data.json

# Scaling down the c-example-couchdbcluster-m sts
oc scale sts c-example-couchdbcluster-m -n $namespace --replicas=0

# Deleting secret aiops-ir-core-model-secret
oc get secret -n $namespace aiops-ir-core-model-secret -o yaml > aiops-ir-core-model-secret-pre-restore.yaml
oc delete secret -n $namespace aiops-ir-core-model-secret

# Deleting all data-c-example-couchdbcluster-m pvc's
pvcList=$(oc get pvc -n $namespace | grep data-c-example-couchdbcluster-m- | cut -d " " -f1)
for pvc in $pvcList; do
    echo PVC name is $pvc
    oc delete pvc -n $namespace $pvc
done

# Scaling down aiops-ir-core-rba-as and aiops-ir-core-rba-rb deployments
oc scale deploy -n $namespace aiops-ir-core-rba-as --replicas=0
oc scale deploy -n $namespace aiops-ir-core-rba-rbs --replicas=0