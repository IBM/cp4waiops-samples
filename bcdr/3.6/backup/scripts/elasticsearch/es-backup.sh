#!/bin/bash
echo "[INFO] $(date) ############## ElasticSearch backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo -e "[INFO] $(date) Running ElasticSearch backup - es-backup.sh, pwd: $CURRENT"

source $WORKDIR/common/common-utils.sh

esBackup="false"

# Reading the related test data file
snapshot_repository_name=$(cat es-backup-config.json | jq -r '.snapshotRepositoryName')  
snapshot_repository_location=$(cat es-backup-config.json | jq -r '.snapshotRepositoryLocaltion')
namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
es_cred_secret_prefix=$(oc get installations.orchestrator.aiops.ibm.com -n $namespace --no-headers |  cut -d " " -f 1)
es_cred_secret=$es_cred_secret_prefix-elastic-secret
echo -e "[INFO] $(date) Reading Elastic Search secret: $es_cred_secret"
indices=$(cat $WORKDIR/common/elasticsearch-indices.json | jq -r '.components[].indices[].name')
actual_indices=$(echo $indices | sed 's/ /,/g')
echo -e "[INFO] $(date) snapshot_repository_name: $snapshot_repository_name | snapshot_repository_location: $snapshot_repository_location | namespace: $namespace" 
echo -e "\n[INFO] $(date) Indices to backup:"
printf "$indices"

# Retrieving elasticsearch db username and password
encoded_username=$(oc get secret $es_cred_secret -o json -n $namespace | jq -r '.data.username')
encoded_password=$(oc get secret $es_cred_secret -o json -n $namespace | jq -r '.data.password')
echo -e "\n"
#echo -e "encoded username: $encoded_username"
username=$(echo $encoded_username | base64 -d)
password=$(echo $encoded_password | base64 -d)
#echo -e "elasticsearch username: $username"
#echo -e "password: $password"

# Retrieving elasticsearch db url
es_url=$(oc get route iaf-system-es -n $namespace -o json | jq -r '.spec.host')
echo -e "[INFO] $(date) elasticSearch URL: $es_url"

echo -e "[INFO] $(date) Register Elasticsearch snapshot repository"
curl -u "$username:$password" -k -X PUT "https://$es_url/_snapshot/$snapshot_repository_name?pretty" -H 'Content-Type: application/json' -d'{"type": "fs","settings": {"location": "'$snapshot_repository_location'","compress": true}}'

snapshot_name=$(echo "snapshot-$(date +%s)")
echo -e "[INFO] $(date) Take Elasticsearch snapshot.  Snapshot name: $snapshot_name"
curl -u "$username:$password" -k -X PUT "https://$es_url/_snapshot/$snapshot_repository_name/$snapshot_name" -H 'Content-Type: application/json' -d'{ "indices": "'$actual_indices'", "ignore_unavailable": true}'

snapshotStatus=$(curl -u "$username:$password" -k "https://$es_url/_snapshot/$snapshot_repository_name/$snapshot_name/_status" | jq -r '.snapshots[0].state' )
echo -e "[INFO] $(date) Snapshot status is $snapshotStatus"

echo "[INFO] $(date) Waiting for 5 sec"
wait "5"

while [ "$snapshotStatus" == "IN_PROGRESS" ] || [ "$snapshotStatus" == "STARTED" ]
do
   echo "[INFO] $(date) Waiting for some time for take snapshot operation to be completed"
   wait "10"
   snapshotStatus=$(curl -u "$username:$password" -k "https://$es_url/_snapshot/$snapshot_repository_name/$snapshot_name/_status" | jq -r '.snapshots[0].state' )
   echo -e "[INFO] $(date) Snapshot status is $snapshotStatus"
done


if [ "$snapshotStatus" == "SUCCESS" ]; then
   echo "[INFO] $(date) Elasticsearch take snapshot opeartion succeeded"
   esBackup="true"
else
   snapshotResoponse=$(curl -u "$username:$password" -k "https://$es_url/_snapshot/$snapshot_repository_name/$snapshot_name/_status")
   echo -e "[INFO] $(date) Snapshot response is $snapshotResoponse"
   echo "[ERROR] $(date) Elasticsearch take snapshot opeartion failed, hence exiting!"
   echo "[WARNING] $(date) Deleting Elasticsearch backup pod"
   oc delete -f es-backup-pod.yaml -n $namespace
   exit 1
fi

echo -e "[INFO] $(date) Create configmap es-bcdr-configmap to store the snapshot name"
oc delete configmap es-bcdr-config -n $namespace 2> /dev/null
oc create configmap es-bcdr-config --from-literal=snapshotName=$snapshot_name --from-literal=snapshotRepositoryName=$snapshot_repository_name --from-literal=snapshotRepositoryLocaltion=$snapshot_repository_location -n $namespace

echo -e "\n"
echo -e "\n[INFO] $(date) List all the snapshots:"
curl -u "$username:$password" -k "https://$es_url/_cat/snapshots/$snapshot_repository_name?v"

echo -e "\n"
echo -e "[INFO] $(date) List all indices:"
echo -e "curl -u $username:*** -k \"https://$es_url/_cat/indices?v\""
curl -u "$username:$password" -k "https://$es_url/_cat/indices?v"

# Updating the backup result for Elasticsearch
if [[ $esBackup == "true" ]]; then
   jq '.elasticsearchBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

echo "[INFO] $(date) ############## ElasticSearch backup completed ##############"
