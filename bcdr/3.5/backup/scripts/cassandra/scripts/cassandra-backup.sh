#!/bin/bash
echo "[INFO] $(date) ############## Cassandra backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source cassandra-utils.sh
source $WORKDIR/common/common-utils.sh

#Pre backup task for cassandra
#Scale down the Agile Service Manager pods.
echo "[WARNING] $(date) Scaling down the Agile Service Manager pods"
./pre-cassandra-backup.sh
echo "[INFO] $(date) Waiting for sometime after scaling down required pods"
wait "90"

#Modify the nodetool command in Cassandra pods, this is a workaround for updating Common Cassandra to use Cassandra 3.11.13
./nodetool-update.sh

#Run a cleanup on all keyspaces in all Cassandra instances
echo "[INFO] $(date) Running the cleanup on all keyspaces in all Cassandra instances"
keyspaces=$(cat cassandra-keyspace.json | jq .keyspaces[].name)
for k in $keyspaces; do
    echo "[INFO] $(date) Cleaning on the keyspace $k"
    kPodLoop aiops-topology-cassandra-[0-9] "nodetool -Dcom.sun.jndi.rmiURLParsing=legacy cleanup $k"
done

echo "[WARNING] $(date) Deleting the previous backups from Cassandra pods"
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
        echo "[ERROR] $(date) No backup tar file is created for Cassandra, hence exiting!"
	 ./post-cassandra-backup.sh
         exit 1
    else
        echo "[INFO] $(date) Backup tar $backup_tarfile file is created successfully!"
    fi

    backup_timestamp=$(echo $backup_tarfile | grep -oP '[\d]+-[\d]+-[\d]+-[\d]+-[\d]+')
    if [ $? -eq 0 ]; then
        echo "[INFO] $(date) Backup timestamp for Cassandra is $backup_timestamp"
    else
        echo "[ERROR] $(date) Unable to retrieve backup timestamp, hence exiting!"
	./post-cassandra-backup.sh
        exit 1
    fi

    json=$(jq --arg t "$backup_timestamp" --arg p "$podName" '. + {($p): $t}' <<<"$json")
    index=$((index + 1))

    podName=""
done

echo $json >$mapFilePath

echo "[INFO] $(date) Creating a configmap to store the timestamp for backup tar file name"
oc delete configmap cassandra-bcdr-config -n $namespace 2> /dev/null
oc create configmap cassandra-bcdr-config --from-file=$mapFilePath -n $namespace

# Deleting a temp file as it is not needed
rm -f $mapFilePath

#Post backup task for cassandra
#Scale up the Agile Service Manager pod to the original level
echo "[INFO] $(date) Scaling up the Agile Service Manager pods once backup is completed"
./post-cassandra-backup.sh
echo "[INFO] $(date) Waiting for sometime after scaling up required pods"
wait "30"

echo "[INFO] $(date) ############## Cassandra backup completed ##############"
