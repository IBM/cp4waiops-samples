#!/bin/bash

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
COUCHDB_RC=$(cat couchdb-rc-data.json | jq -r '.COUCHDB_RC')
RBA_AS_RC=$(cat couchdb-rc-data.json | jq -r '.RBA_AS_RC')
RBS_RC=$(cat couchdb-rc-data.json | jq -r '.RBS_RC')
echo $namespace $COUCHDB_RC $RBA_AS_RC $RBS_RC

# Deleting couchdb backup pod
oc delete po -n $namespace -l couchdb.cp4aiops.ibm.com/backup=t

# Scaling up aiops-ir-core-rba-as and aiops-ir-core-rba-rbs deployments
oc scale deploy -n $namespace aiops-ir-core-rba-as --replicas=$RBA_AS_RC
oc scale deploy -n $namespace aiops-ir-core-rba-rbs --replicas=$RBS_RC

# Scaling up c-example-couchdbcluster-m statefulset
oc scale sts c-example-couchdbcluster-m -n $namespace --replicas=$COUCHDB_RC
