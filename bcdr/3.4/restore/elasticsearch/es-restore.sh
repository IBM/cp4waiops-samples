#!/bin/bash

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo -e "Running ElasticSearch restore - es-restore.sh, pwd: $CURRENT"

source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
es_cred_secret_prefix=$(oc get installations.orchestrator.aiops.ibm.com -n $namespace --no-headers |  cut -d " " -f 1)
es_cred_secret=$es_cred_secret_prefix-elastic-secret
echo -e "Reading Elastic Search secret: $es_cred_secret"

# Retrieving snapshot details
snapshot_name=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotName')
snapshot_repository_location=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotRepositoryLocaltion')
snapshot_repository_name=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotRepositoryName')
echo $snapshot_name $snapshot_repository_location $snapshot_repository_name

# Retrieving elasticsearch db username and password
encoded_username=$(oc get secret $es_cred_secret -o json -n $namespace | jq -r '.data.username')
encoded_password=$(oc get secret $es_cred_secret -o json -n $namespace | jq -r '.data.password')
echo -e "\n"
#echo -e "encoded username: $encoded_username"
username=$(echo $encoded_username | base64 -d)
password=$(echo $encoded_password | base64 -d)
#echo -e "elasticsearch username: $username"

# Retrieving elasticsearch db hostname
es_hostname=$(oc get route iaf-system-es -n $namespace -o json | jq -r '.spec.host')
echo -e "elasticsearch url: https://$es_hostname"

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "iaf-system-elasticsearch-es-snap-es-backup-pvc"

echo -e "Unregister the previously registered bcdr snapshot repository"
curl -u "$username:$password" -k -X DELETE "https://$es_hostname/_snapshot/$snapshot_repository_name?pretty"

echo "Wait 5 sec after unregistering snapshot repository"
wait "5"

echo -e "Register Elasticsearch snapshot repository"
curl -u "$username:$password" -k -X PUT "https://$es_hostname/_snapshot/$snapshot_repository_name?pretty" -H 'Content-Type: application/json' -d'{"type": "fs","settings": {"location": "'$snapshot_repository_location'","compress": true}}'

# Retrieve all the open indices
openIndices=$(curl -s -u "$username:$password" -k -X GET "https://$es_hostname/_cat/indices?h=status,index" | awk '$1 == "open" {print $2}')
echo "Open indices are"
echo $openIndices

echo -e "Closing all open indices as it's required before restore"
for indice in $openIndices; do
    echo "Closing indice $indice"
    curl -u "$username:$password" -k -X POST "https://$es_hostname/$indice/_close?pretty" -H 'Content-Type: application/json'
done

echo -e "Restore snapshot"
curl -u "$username:$password" -k -X POST "https://$es_hostname/_snapshot/$snapshot_repository_name/$snapshot_name/_restore?wait_for_completion=true" -H 'Content-Type: application/json'

# Retrieve all the closed indices
closedIndices=$(curl -s -u "$username:$password" -k -X GET "https://$es_hostname/_cat/indices?h=status,index" | awk '$1 == "close" {print $2}')
echo "Closed indices are"
echo $closedIndices

echo -e "Opening all closed indices after restore"
for indice in $closedIndices; do
    echo "Opening indice $indice"
    curl -u "$username:$password" -k -X POST "https://$es_hostname/$indice/_open?pretty" -H 'Content-Type: application/json'
done

# Deleting restored resources
oc delete pod es-backup -n $namespace
oc delete cm es-bcdr-config -n $namespace

echo "Elasticsearch restore is completed"
