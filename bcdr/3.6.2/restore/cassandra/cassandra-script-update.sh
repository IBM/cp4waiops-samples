#!/bin/bash
source $WORKDIR/restore/cassandra/cassandra-utils.sh


cassandraextrapod=$(oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[1-9])

if [ -n "$cassandraextrapod" ]; then
    echo "[INFO] $(date) This is multinode cassandra cluster, hence updating the cassandra_functions.sh for other nodes"
    
    #update the cassandra_functions.sh for restore operation and then copying it to other pods of Cassandra in HA cluster
    echo "[INFO] $(date) Updating and copying the cassandra_functions.sh to other Cassandra pods in HA cluster"
    oc cp -n $namespace aiops-topology-cassandra-0:/opt/ibm/backup_scripts/cassandra_functions.sh /tmp/cassandra_functions.sh
    sed -zi 's/truncate_all_tables/#truncate_all_tables/2'  /tmp/cassandra_functions.sh
    sed -zi 's/testResult $? "truncate tables"/#testResult $? "truncate tables"/'  /tmp/cassandra_functions.sh

    #Copy the updated cassandra_functions.sh to other cassandra nodes except first one
    for pod in $cassandraextrapod; do
        oc cp -n $namespace  /tmp/cassandra_functions.sh $pod:/opt/ibm/backup_scripts/cassandra_functions.sh
    done
else
    echo "[INFO] $(date) This is single node Cassandra cluster, so no need to update cassandra_functions.sh"
fi

