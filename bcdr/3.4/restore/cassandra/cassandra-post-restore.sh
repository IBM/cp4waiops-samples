#!/bin/bash

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
CASSANDRA_RC=$(cat cassandra-rc-data.json | jq -r '.CASSANDRA_RC')
echo $namespace $CASSANDRA_RC

echo "Deleting the backup pods"
oc delete pod -n $namespace -l cassandra.cp4aiops.ibm.com/backup=t

echo "Scaling up the aiops-topology-cassandra statefulset"
oc scale sts aiops-topology-cassandra -n $namespace --replicas=$CASSANDRA_RC
