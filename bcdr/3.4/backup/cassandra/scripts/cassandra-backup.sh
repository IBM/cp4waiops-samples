#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source cassandra-utils.sh
source ../../../common/common-utils.sh

#Pre backup task for cassandra
#Scale down the Agile Service Manager pods.
echo "Scaling down the Agile Service Manager pods ......."
./pre-cassandra-backup.sh
echo "Waiting for sometime after scaling down required pods"
wait "90"

#Run a cleanup on all keyspaces in all Cassandra instances
echo "Running the cleanup on all keyspaces in all Cassandra instances....."
keyspaces=$(cat cassandra-keyspace.json | jq .keyspaces[].name)
for k in $keyspaces; do
    echo "Cleaning on the keyspace $k..."
    kPodLoop aiops-topology-cassandra-[0-9] "nodetool cleanup $k"
done

echo "Deleting the previous backups from Cassandra pods"
cassandnodes=$(oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9])
for pod in $cassandnodes; do
    oc exec $pod -n $namespace -- bash -c " rm -rf /opt/ibm/cassandra/data/backup_tar/*"
done

# Trigger backup: run backup on all Cassandra instances
./trigger-cassandra-backup.sh

# Creating a configmap to store the timestamp for backup tar file name
replicas=$(oc get sts aiops-topology-cassandra -n ${namespace} -o jsonpath='{.spec.replicas}')

index=0
mapFilePath="/tmp/cassandra-config-data-map.json"
json="{}"

# Removing file before creation
rm -f $mapFilePath

while [ $index -lt $replicas ]; do
    podName+="aiops-topology-cassandra-"
    podName+=$index

    backup_tarfile=$(oc exec $podName -n $namespace -- bash -c "ls /opt/ibm/cassandra/data/backup_tar -rt | tail -1")
    if [ -z "$backup_tarfile" ]; then
        echo "No backup tar file is created for Cassandra, hence exiting!"
         exit 1
    else
        echo "Backup tar $backup_tarfile file is created successfully!"
    fi

    backup_timestamp=$(echo $backup_tarfile | grep -oP '[\d]+-[\d]+-[\d]+-[\d]+-[\d]+')
    if [ $? -eq 0 ]; then
        echo "Backup timestamp for Cassandra is $backup_timestamp"
    else
        echo "Unable to retrieve backup timestamp, hence exiting!"
        exit 1
    fi

    json=$(jq --arg t "$backup_timestamp" --arg p "$podName" '. + {($p): $t}' <<<"$json")
    index=$((index + 1))

    podName=""
done

echo $json >$mapFilePath

echo "Creating a configmap to store the timestamp for backup tar file name"
oc delete configmap cassandra-bcdr-config -n $namespace 2> /dev/null
oc create configmap cassandra-bcdr-config --from-file=$mapFilePath -n $namespace

# Deleting a temp file as it is not needed
rm -f $mapFilePath

#Post backup task for cassandra
#Scale up the Agile Service Manager pod to the original level
echo "Scaling up the Agile Service Manager pods once backup is completed......."
./post-cassandra-backup.sh
echo "Waiting for sometime after scaling up required pods"
wait "30"
