#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

source $WORKDIR/restore/cassandra/cassandra-utils.sh

echo "[INFO] $(date) Updating the nodetool command"
cassandnodes=$(oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9])
for pod in $cassandnodes; do
    oc cp -n $namespace $WORKDIR/restore/cassandra/cassandra_functions.sh $pod:/opt/ibm/backup_scripts/cassandra_functions.sh
done
