#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

source cassandra-utils.sh

echo "[INFO] $(date) Updating the nodetool command"
cassandnodes=$(oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9])
for pod in $cassandnodes; do
    oc cp -n $namespace cassandra_functions.sh $pod:/opt/ibm/backup_scripts/cassandra_functions.sh
done
