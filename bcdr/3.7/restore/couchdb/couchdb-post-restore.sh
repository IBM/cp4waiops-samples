#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

echo "[INFO] $(date) ############## IBM Couchdb post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
COUCHDB_RC=$(cat $WORKDIR/restore/couchdb/couchdb-rc-data.json | jq -r '.COUCHDB_RC')
RBA_AS_RC=$(cat $WORKDIR/restore/couchdb/couchdb-rc-data.json | jq -r '.RBA_AS_RC')
RBS_RC=$(cat $WORKDIR/restore/couchdb/couchdb-rc-data.json | jq -r '.RBS_RC')
IRCORE_RC=$(cat $WORKDIR/restore/couchdb/couchdb-rc-data.json | jq -r '.IRCORE_RC')
echo "[INFO] $(date) namespace: $namespace, COUCHDB_RC: $COUCHDB_RC, RBA_AS_RC: $RBA_AS_RC, RBS_RC: $RBS_RC, IRCORE_RC: $IRCORE_RC"

echo "[WARNING] $(date) Deleting couchdb backup pods"
oc delete po -n $namespace -l couchdb.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up ir-core-operator-controller-manager deployment"
oc scale deploy -n $namespace  ir-core-operator-controller-manager --replicas=$IRCORE_RC

echo "[INFO] $(date) Scaling up aiops-ir-core-rba-as and aiops-ir-core-rba-rbs deployments"
oc scale deploy -n $namespace aiops-ir-core-rba-as --replicas=$RBA_AS_RC
oc scale deploy -n $namespace aiops-ir-core-rba-rbs --replicas=$RBS_RC
 
echo "[INFO] $(date) Scaling up c-example-couchdbcluster-m statefulset"
oc scale sts c-example-couchdbcluster-m -n $namespace --replicas=$COUCHDB_RC
