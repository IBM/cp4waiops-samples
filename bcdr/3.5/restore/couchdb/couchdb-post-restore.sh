#!/bin/bash

echo "[INFO] $(date) ############## IBM Couchdb post-restore process has started ##############"

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
COUCHDB_RC=$(cat couchdb-rc-data.json | jq -r '.COUCHDB_RC')
RBA_AS_RC=$(cat couchdb-rc-data.json | jq -r '.RBA_AS_RC')
RBS_RC=$(cat couchdb-rc-data.json | jq -r '.RBS_RC')
echo "[INFO] $(date) namespace: $namespace, COUCHDB_RC: $COUCHDB_RC, RBA_AS_RC: $RBA_AS_RC, RBS_RC: $RBS_RC"

echo "[WARNING] $(date) Deleting couchdb backup pods"
oc delete po -n $namespace -l couchdb.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up aiops-ir-core-rba-as and aiops-ir-core-rba-rbs deployments"
oc scale deploy -n $namespace aiops-ir-core-rba-as --replicas=$RBA_AS_RC
oc scale deploy -n $namespace aiops-ir-core-rba-rbs --replicas=$RBS_RC
 
echo "[INFO] $(date) Scaling up c-example-couchdbcluster-m statefulset"
oc scale sts c-example-couchdbcluster-m -n $namespace --replicas=$COUCHDB_RC
