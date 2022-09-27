#!/bin/bash
echo "[INFO] $(date) ############## Common services backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
DUMMY_DB_FILE_PATH=$BASEDIR/dummy-db.yaml
namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')
echo "[INFO] $(date) Common service namespace is $namespace"
csBackup="false"

# Replace MONGODB_DUMP_IMAGE with actual image value in file mongodb-dump.yaml
mongodb_dump_image=$(oc get sts icp-mongodb -o jsonpath='{.spec.template.spec.containers[?(@.name == "icp-mongodb")].image}' -n $namespace)
echo "[INFO] $(date) Mongodb dump job image value is $mongodb_dump_image"
sed -i "s~MONGODB_DUMP_IMAGE~$mongodb_dump_image~g" mongodb-dump.yaml
sed -i "s~MONGODB_DUMP_IMAGE~$mongodb_dump_image~g" mongo-image-policy.yaml

# Creating a configmap to store the mongodb_dump_image
oc delete configmap cs-bcdr-config -n $namespace 2> /dev/null
oc create configmap cs-bcdr-config --from-literal=mongoDumpImage=$mongodb_dump_image -n $namespace

# Function to wait for a specific time, it requires one positional argument i.e timeout
wait() {
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
      printf "."
      sleep 1
      i=$((i+1))
   done
}

# Function to check resource readyness, it requires 4 positional arguments such as namespace, jobLabel, retryCount and resourceType
checkResourceReadyness() {
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0
   resources=$(oc -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
   echo "[INFO] $(date) Resources: $resources"

   while [ "${resources}" ]; do
      wait "5"
      echo "[INFO] $(date) Waiting for resource to be READY"

      resources=$(oc -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
      echo "[INFO] $(date) Resources: $resources"

      counter=$((counter+1))
      echo "[INFO] $(date) Counter: $counter, RetryCount: $retryCount"

      if [ $counter -eq $retryCount ]; then
         echo "[INFO] $(date) $resources are not ready"
         break
      fi
   done
}

# Updates the DUMMY_DB_FILE_PATH only if environment is air gap
updateDummyDBFilePath() {
   if [ "$AIR_GAP" = "true" ]; then
      DUMMY_DB_FILE_PATH=$BASEDIR/dummy-db-airgap.yaml
      echo "[INFO] $(date) Updated dummy db file path to $DUMMY_DB_FILE_PATH as value of env variable AIR_GAP is $AIR_GAP"
   else
      echo "[INFO] $(date) Not updating dummy db file path $DUMMY_DB_FILE_PATH as value of env variable AIR_GAP is $AIR_GAP"
   fi
}

# Wait till deletion of resource
waitTillDeletionComplete(){
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0

   resourceCount=$(oc get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
   echo "[INFO] $(date) Resource count: $resourceCount"

   while [ $resourceCount -ne 0 ]; do
      wait "5"
      echo "[INFO] $(date) Waiting for resource to be Deleted"

      resourceCount=$(oc get $resourceType -l $resourceLabel -n $namespace --no-headers | wc -l)
      echo "[INFO] $(date) Resource count: $resourceCount"

      counter=$((counter+1))
      echo "[INFO] $(date) Counter: $counter, RetryCount: $retryCount"

      if [ $counter -eq $retryCount ]; then
         echo "[WARNING] $(date) Exiting from waitTillDeletionComplete function as retryCount threshold achieved"
         break
      fi
   done

}

# Check and update the dummy db file path
#updateDummyDBFilePath

# Applying Cluster Image Policy for MongoDB & Nginx
#The following two steps will be needed for cluster in AWS
#oc apply -f $BASEDIR/mongo-image-policy.yaml
#oc apply -f $BASEDIR/nginx-image-policy.yaml

oc delete -f $DUMMY_DB_FILE_PATH -n $namespace 2> /dev/null 
waitTillDeletionComplete "$namespace" "app=dummy-db" "4" "pod"
oc delete -f $BASEDIR/mongodb-dump.yaml -n $namespace 2> /dev/null
waitTillDeletionComplete "$namespace" "name=my-mongodump" "4" "pvc"
pvcCount=$(oc get pvc -l name=my-mongodump -n $namespace --no-headers | wc -l)
if [ $pvcCount -ne 0 ]; then
   oc delete pvc -l name=my-mongodump -n $namespace --force
   waitTillDeletionComplete "$namespace" "name=my-mongodump" "4" "pvc"
fi
oc apply -f $BASEDIR/mongodb-dump.yaml -n $namespace
checkResourceReadyness "$namespace" "job-name=icp-mongodb-backup" "50" "job"

mongodbBackupJobStatus=$(oc get pods -n $namespace -o=jsonpath='{.items[*].status.phase}{"\n"}' -l job-name=icp-mongodb-backup)
echo "[INFO] $(date) Common services mongodb backup job status is $mongodbBackupJobStatus"
if [ "$mongodbBackupJobStatus" == "Succeeded" ]; then
   echo "[INFO] $(date) Execution of common services mongodb backup succeeded"
   csBackup="true"
   oc create -f $DUMMY_DB_FILE_PATH -n $namespace
   checkResourceReadyness "$namespace" "app=dummy-db" "40" "pod"

else
   echo "[ERROR] $(date) Execution of common services mongodb backup failed, hence exiting!"
   oc delete -f $BASEDIR/mongodb-dump.yaml -n $namespace
   exit 1
fi

# Updating the backup result for common-services
if [[ $csBackup == "true" ]]; then
   jq '.commonservicesBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi
echo "[INFO] $(date) ############## Common services backup completed ##############"

