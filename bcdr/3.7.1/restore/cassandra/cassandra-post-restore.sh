#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

echo "[INFO] $(date) ############## IBM Cassandra post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
CASSANDRA_RC=$(cat $WORKDIR/restore/cassandra/cassandra-rc-data.json | jq -r '.CASSANDRA_RC')
echo "[INFO] $(date) namespace: $namespace, CASSANDRA_RC: $CASSANDRA_RC"

echo "[INFO] $(date) Deleting the backup pods"
oc delete pod -n $namespace -l cassandra.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up the aiops-topology-cassandra statefulset"
oc scale sts aiops-topology-cassandra -n $namespace --replicas=$CASSANDRA_RC
