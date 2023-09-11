#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

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

# if [ "$esClusterHealthStatus" != "green" ]; then
#     echo "[INFO] $(date) Terminating the restore process as elasticsearch cluster status is not green"
#     echo "[WARNING] $(date) Deleting restored resources"
#     ./es-post-restore.sh
#     exit 1
# fi

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

echo -e "[INFO] $(date) Waiting for some time before checking snapshot restore status"
wait "60"

# Fetching indices list from restore snapshot details
snapshotDetails=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_snapshot/$snapshot_repository_name/$snapshot_name/_status?pretty")
indicesJson=$(echo $snapshotDetails | jq -r '.snapshots[0].indices')
indices=$(echo $indicesJson | jq -r 'keys[]')
echo "[INFO] $(date) Indices list fetched from snapshot details:"
echo "$indices"

# Iterating over each index for validating restore status
# Index restore validation will be performed based on restored snapshot name(from which snapshot restore is performed) and byte recovery percentage values. These values will be fetched from index recovery details.
for indice in $indices; do
   # Fetching restored snapshot name value from index recovery details, sometimes there will be duplicate recovery records for a particular index hence restored snapshot name values are collected in an array
   echo "[INFO] $(date) Checking restore progress of index $indice"
   restored_snapshot_values=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_cat/recovery/$indice?h=snapshot")
   # converting the above retrived values to array
   restored_snapshot_array=($restored_snapshot_values)
   echo "[DEBUG] $(date) restored_snapshot_array: ${restored_snapshot_array[@]}"
   echo "[DEBUG] $(date) Number of elements in the restored_snapshot_array: ${#restored_snapshot_array[@]}"
   # Till the time snapshot restore is not started for an index then the restored snapshot name property value will be blank in cat recovery details so waiting till it's changed to something from blank
   while [ "${#restored_snapshot_array[@]}" == "0" ]
      do
        echo "[INFO] $(date) Restore result for index $indice is blank, waiting for some time"
        wait "5"
        restored_snapshot_values=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_cat/recovery/$indice?h=snapshot")
        # converting the above retrived values to array
        restored_snapshot_array=($restored_snapshot_values)
        echo "[DEBUG] $(date) restored_snapshot_array: ${restored_snapshot_array[@]}"
        echo "[DEBUG] $(date) Number of elements in the restored_snapshot_array: ${#restored_snapshot_array[@]}"
   done
 
   target_snapshot_found="false"
   while [ "${target_snapshot_found}" != "true" ]
    do
        # Iterating over all the restored snapshot names when there is duplicate records 
        for restored_snapshot in ${!restored_snapshot_array[@]}; do
            echo "[DEBUG] $(date) Restored snapshot value at index $restored_snapshot is ${restored_snapshot_array[$restored_snapshot]}"
            if [ "${restored_snapshot_array[$restored_snapshot]}" == "$snapshot_name" ]; then
                target_snapshot_found="true"
                echo "[INFO] $(date) Target snapshot ${restored_snapshot_array[$restored_snapshot]} is found for indice $indice"
                break
            fi
        done

        if [ "${target_snapshot_found}" != "true" ]; then
            echo "[INFO] $(date) Restore is not started for index $indice, waiting for some time"
            wait "5"
            restored_snapshot_values=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_cat/recovery/$indice?h=snapshot")
            # converting the above retrived values to array
            restored_snapshot_array=($restored_snapshot_values)
        fi
   done   

   # Fetching byte percentage value from index recovery details, sometimes there will be duplicate recovery records for a particular index hence byte percentage values are collected in an array
   restored_byte_percentage_values=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_cat/recovery/$indice?h=bp")
   # converting the above retrived values to array
   restored_byte_percentage_array=($restored_byte_percentage_values)
   echo "[DEBUG] $(date) restored_byte_percentage_array: ${restored_byte_percentage_array[@]}"
   echo "[DEBUG] $(date) Number of elements in the restored_byte_percentage_array: ${#restored_byte_percentage_array[@]}"

   # Iterating over all the byte percentage values when there is duplicate records 
   for restored_byte_percentage in ${!restored_byte_percentage_array[@]}; do
     echo "[DEBUG] $(date) Restored byte percentage value at index $restored_byte_percentage  is ${restored_byte_percentage_array[$restored_byte_percentage]}"
     
     # Waiting till byte percentage value is changed to 100%
     while [ "${restored_byte_percentage_array[$restored_byte_percentage]}" != "100.0%" ]
     do
       echo "[INFO] $(date) Restore is not completed for index $indice, waiting for some time"
       wait "5"
       restored_byte_percentage_values=$(curl -u "$username:$password" -k -X GET "https://$es_hostname/_cat/recovery/$indice?h=bp")
       # converting the above retrived values to array
       restored_byte_percentage_array=($restored_byte_percentage_values)
       echo "[DEBUG] $(date) Current restored byte percentage value is ${restored_byte_percentage_array[$restored_byte_percentage]}"
     done
   done

   echo "[INFO] $(date) Restore completed for index $indice"
   
done

# Retrieve all the closed indices
closedIndices=$(curl -s -u "$username:$password" -k -X GET "https://$es_hostname/_cat/indices?h=status,index" | awk '$1 == "close" {print $2}')
echo "[INFO] $(date) Closed indices are:"
echo $closedIndices

echo -e "[INFO] $(date) Opening all closed indices after restore"
for indice in $closedIndices; do
    echo "[INFO] $(date) Opening indice $indice"
    curl -u "$username:$password" -k -X POST "https://$es_hostname/$indice/_open?pretty" -H 'Content-Type: application/json'
done

echo "[WARNING] $(date) Restarting aimanager-aio-ai-platform-api-server-xxxxx, connector-bridge, change-risk and datarouting pods"
oc delete pod -l icpdsupport/app=ai-platform-api-server -n $namespace
oc delete pod  -l app=connector-bridge -n $namespace
oc delete pod  -l icpdsupport/app=change-risk -n $namespace
oc delete pod -l app=ibm-grpc-snow-connector -n $namespace
oc delete pod -l app.kubernetes.io/component=datarouting -n $namespace
oc delete pod -l  app.kubernetes.io/component=aiops-insights-ui-datarouting -n $namespace

echo "[WARNING] $(date) Deleting restored resources"
$WORKDIR/restore/elasticsearch/es-post-restore.sh

echo "[INFO] $(date) ############## ElasticSearch restore completed ##############"
