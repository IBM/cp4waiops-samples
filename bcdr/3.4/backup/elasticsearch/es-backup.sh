#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo -e "Running ElasticSearch backup - es-backup.sh, pwd: $CURRENT"

# Reading the related test data file
snapshot_repository_name=$(cat es-backup-config.json | jq -r '.snapshotRepositoryName')  
snapshot_repository_location=$(cat es-backup-config.json | jq -r '.snapshotRepositoryLocaltion')
namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
es_cred_secret_prefix=$(oc get installations.orchestrator.aiops.ibm.com -n $namespace --no-headers |  cut -d " " -f 1)
es_cred_secret=$es_cred_secret_prefix-elastic-secret
echo -e "Reading Elastic Search secret: $es_cred_secret"
indices=$(cat ../../common/elasticsearch-indices.json | jq -r '.components[].indices[].name')
actual_indices=$(echo $indices | sed 's/ /,/g')
echo -e "snapshot_repository_name: $snapshot_repository_name | snapshot_repository_location: $snapshot_repository_location | namespace: $namespace" 
echo -e "\nIndices to backup:"
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
echo -e "elasticSearch URL: $es_url"

echo -e "Register Elasticsearch snapshot repository"
curl -u "$username:$password" -k -X PUT "https://$es_url/_snapshot/$snapshot_repository_name?pretty" -H 'Content-Type: application/json' -d'{"type": "fs","settings": {"location": "'$snapshot_repository_location'","compress": true}}'


snapshot_name=$(echo "snapshot-$(date +%s)")
echo -e "Take Elasticsearch snapshot.  Snapshot name: $snapshot_name"
takeSnapshotResponse=$(curl -u "$username:$password" -k -X PUT "https://$es_url/_snapshot/$snapshot_repository_name/$snapshot_name?wait_for_completion=true&master_timeout=30m" -H 'Content-Type: application/json' -d'{ "indices": "'$actual_indices'", "ignore_unavailable": true}')
echo "Take snapeshot response is $takeSnapshotResponse"
snapshotStatus=$(echo $takeSnapshotResponse | jq -r '.snapshot.state')
echo -e "Snapshot status is $snapshotStatus"
if [ "$snapshotStatus" == "SUCCESS" ]; then
   echo "Elasticsearch take snapshot opeartion succeeded"
else
   echo "Elasticsearch take snapshot opeartion failed, hence exiting!"
   echo "Deleting Elasticsearch backup pod"
   oc delete -f es-backup-pod.yaml -n $namespace
   exit 1
fi

echo -e "Create configmap es-bcdr-configmap to store the snapshot name"
oc delete configmap es-bcdr-config -n $namespace 2> /dev/null
oc create configmap es-bcdr-config --from-literal=snapshotName=$snapshot_name --from-literal=snapshotRepositoryName=$snapshot_repository_name --from-literal=snapshotRepositoryLocaltion=$snapshot_repository_location -n $namespace

echo -e "\n"
echo -e "\nList all the snapshots:"
curl -u "$username:$password" -k "https://$es_url/_cat/snapshots/$snapshot_repository_name?v"

echo -e "\n"
echo -e "List all indices:"
echo -e "curl -u $username:*** -k \"https://$es_url/_cat/indices?v\""
curl -u "$username:$password" -k "https://$es_url/_cat/indices?v"
