#!/bin/bash

source cassandra-utils.sh

cassandrarestore(){
    
    ## TODO: Remove below commented code once new code changes are tested
    # manual_input=$(cat backup-timestamp.json | jq -r .manualinput)
    # if [[ "$manual_input" == 'false' ]]
    # then
	# echo "Updating then backup timestamp for cassandra with latest available backup tar"
    #     backup_timestamp=$( oc get cm cassandra-bcdr-config -o json -n $namespace | jq -r '.data.backupTimestamp' )
    #     jq -c --arg backup_timestamp "$backup_timestamp" '.backuptimestamp = $backup_timestamp' backup-timestamp.json > tmp.$$.json && mv tmp.$$.json backup-timestamp.json
    # fi

    # backuptimestamp=$(cat backup-timestamp.json | jq .backuptimestamp)

    cassandrapods=$(oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9])
    keyspaces=$(cat cassandra-keyspace.json | jq .keyspaces[].name)

    podTimestampMap=$(oc get cm cassandra-bcdr-config -o jsonpath='{.data.cassandra-config-data-map\.json}' -n $namespace)
    echo "Cassandra Pods and Backup timestamp map: $podTimestampMap"


    for keyspace in $keyspaces; do
        for pod in $cassandrapods; do
            # Retrieving backup timestamp from cassandra-bcdr-config configmap
            backuptimestamp=$(jq -r --arg k $pod '.[$k]' <<< "$podTimestampMap")
            echo "Restoring the keyspace $keyspace on pod $pod"
            kPodLoop $pod "/opt/ibm/backup_scripts/restore_cassandra.sh -k $keyspace  -t $backuptimestamp -u \${CASSANDRA_USER} -p \${CASSANDRA_PASS} -f"
        done
    done
}

cassandrarestore
