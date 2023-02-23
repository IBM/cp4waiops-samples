#!/bin/bash

echo "[INFO] $(date) ############## ElasticSearch restore started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo -e "[INFO] $(date) Running ElasticSearch restore - es-restore.sh, pwd: $CURRENT"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

echo -e "[INFO] $(date) Executing elasticsearch pre restore script"
$WORKDIR/restore/elasticsearch/es-pre-restore.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

es_cred_secret_prefix=$(oc get installations.orchestrator.aiops.ibm.com -n $namespace --no-headers |  cut -d " " -f 1)
es_cred_secret=$es_cred_secret_prefix-elastic-secret
echo -e "[INFO] $(date) Reading Elastic Search secret: $es_cred_secret"

# Retrieving snapshot details
snapshot_name=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotName')
snapshot_repository_location=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotRepositoryLocaltion')
snapshot_repository_name=$(oc get cm es-bcdr-config -o json -n $namespace | jq -r '.data.snapshotRepositoryName')
echo "[INFO] $(date) snapshot_name: $snapshot_name, snapshot_repository_location: $snapshot_repository_location, snapshot_repository_name: $snapshot_repository_name"

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
echo -e "[INFO] $(date) elasticsearch url: https://$es_hostname"

echo -e "[INFO] $(date) Unregister the previously registered bcdr snapshot repository"
curl -u "$username:$password" -k -X DELETE "https://$es_hostname/_snapshot/$snapshot_repository_name?pretty"

echo "[INFO] $(date) Wait 5 sec after unregistering snapshot repository"
wait "5"

echo -e "[INFO] $(date) Register Elasticsearch snapshot repository"
curl -u "$username:$password" -k -X PUT "https://$es_hostname/_snapshot/$snapshot_repository_name?pretty" -H 'Content-Type: application/json' -d'{"type": "fs","settings": {"location": "'$snapshot_repository_location'","compress": true}}'

esClusterHealthStatus=$(curl -u "$username:$password" -k "https://$es_hostname/_cluster/health?pretty" | jq -r '.status' )
echo -e "[INFO] $(date) Before performing snapshot restore, elasticsearch cluster health status is $esClusterHealthStatus"
if [ "$esClusterHealthStatus" != "green" ]; then
    echo "[ERROR] $(date) Terminating the restore process as elasticsearch cluster status is not green"
    echo "[WARNING] $(date) Deleting restored resources"
    $WORKDIR/restore/elasticsearch/es-post-restore.sh
    exit 1
fi

# Retrieve all the open indices
openIndices=$(curl -s -u "$username:$password" -k -X GET "https://$es_hostname/_cat/indices?h=status,index" | awk '$1 == "open" {print $2}')
echo "[INFO] $(date) Open indices are:"
echo $openIndices

echo -e "[INFO] $(date) Closing all open indices as it's required before restore"
for indice in $openIndices; do
    echo "[INFO] $(date) Closing indice $indice"
    curl -u "$username:$password" -k -X POST "https://$es_hostname/$indice/_close?pretty" -H 'Content-Type: application/json'
done

echo -e "[INFO] $(date) Restore snapshot"
curl -u "$username:$password" -k -X POST "https://$es_hostname/_snapshot/$snapshot_repository_name/$snapshot_name/_restore" -H 'Content-Type: application/json'

esClusterHealthStatus=$(curl -u "$username:$password" -k "https://$es_hostname/_cluster/health?pretty" | jq -r '.status' )
echo -e "[INFO] $(date) Elasticsearch cluster health status is $esClusterHealthStatus"

echo "[INFO] $(date) Waiting for 5 sec"
wait "5"

counter=0
estimeout=45

while [ "$esClusterHealthStatus" == "yellow" ] && [ $counter -ne $estimeout ]; do
  echo "[INFO] $(date) Waiting for elasticsearch cluster health status to be green"
  wait "60"
  ((counter++))
  esClusterHealthStatus=$(curl -u "$username:$password" -k "https://$es_hostname/_cluster/health?pretty" | jq -r '.status' )
  echo -e "[INFO] $(date) Elasticsearch cluster health status is $esClusterHealthStatus"
done

if [ "$esClusterHealthStatus" == "yellow" ] && [ $counter -eq $estimeout ]; then
   echo -e "[WARNING] $(date) Elasticsearch cluster health status is $esClusterHealthStatus after waiting maximum time, proceeding with further elasticsearch restore steps"
fi

# Retrieve all the closed indices
closedIndices=$(curl -s -u "$username:$password" -k -X GET "https://$es_hostname/_cat/indices?h=status,index" | awk '$1 == "close" {print $2}')
echo "[INFO] $(date) Closed indices are:"
echo $closedIndices

echo -e "[INFO] $(date) Opening all closed indices after restore"
for indice in $closedIndices; do
    echo "[INFO] $(date) Opening indice $indice"
    curl -u "$username:$password" -k -X POST "https://$es_hostname/$indice/_open?pretty" -H 'Content-Type: application/json'
done

echo "[WARNING] $(date) Restarting aimanager-aio-ai-platform-api-server-xxxxx, connector-bridge, change-risk pods"
oc delete pod -l icpdsupport/app=ai-platform-api-server -n $namespace
oc delete pod  -l app=connector-bridge -n $namespace
oc delete pod  -l icpdsupport/app=change-risk -n $namespace
oc delete pod -l app=ibm-grpc-snow-connector -n $namespace

echo "[WARNING] $(date) Deleting restored resources"
$WORKDIR/restore/elasticsearch/es-post-restore.sh

echo "[INFO] $(date) ############## ElasticSearch restore completed ##############"
