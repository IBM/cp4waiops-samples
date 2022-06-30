#!/bin/bash

#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================

CURRENT=$(pwd)
log_file="$CURRENT/restore.log"

source ../../common/common-utils.sh
veleronamespace=$(cat ../../common/aiops-config.json | jq -r '.veleroNamespace')

echo "=============================================" | tee -a "$log_file"

# This functio is to print restore status message
printRestoreStatus() {
   if [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
      echo "Restore is PartiallyFailed hence retrying the restore again"
   elif [[ "$restoreStatus" == 'Completed' ]]; then
      echo "Restore is Completed"
   elif [[ "$restoreStatus" == '' ]]; then
      echo ""
   else
      echo "Restore status is: $restoreStatus"
   fi
}

# This function is to check whether backup exists or not, it accepts one positional argument i.e backupName
checkBackup() {
   echo "Backup name is $backupName"
   velero get backup $backupName
   if [ $? -eq 0 ]; then
      echo "Backup exists" | tee -a "$log_file"
   else
      echo "Backup not found hence terminating restore process" | tee -a "$log_file"
      exit 1
   fi
}

# This function is to check the restore status periodically till it completes, it accepts one positional argument i.e restoreName
waitTillRestoreCompletion() {
   restoreName=$1
   echo Restore name passed to func waitTillRestoreCompletion is: $restoreName | tee -a "$log_file"
   wait "10"
   restoreStatus=$(oc get restore $restoreName -n $veleronamespace -o=jsonpath='{.status.phase}')
   echo Initial velero restore status is: $restoreStatus | tee -a "$log_file"
   
   while [ "$restoreStatus" == "InProgress" ] || [ "$restoreStatus" == "New" ]
   do
     echo "Waiting for 1 min" | tee -a "$log_file"
     wait "60"
     restoreStatus=$(oc get restore $restoreName -n $veleronamespace -o=jsonpath='{.status.phase}')
     echo Velero restore status is: $restoreStatus | tee -a "$log_file"
   done
}

# Function to check if a particular restore exists or not
checkRestoreExistsOrNot() {
   restoreName=$1
   command="velero get restore $restoreName"
   $(echo $command)
   op=$(echo $?)

   if [[ "$op" -eq 0 ]]; then
      isRestoreExists="true"
      echo "Restore exists"
   else
      isRestoreExists="false"
      echo "Restore does not exist"
   fi
}

# This function is to perform restore
performVeleroRestore() {
   restoreNamePrefix=$1
   backupName=$2
   namespace=$3
   restoreLabel=$4
   checkBackup "$backupName"

   for i in {0..1}; do
      restoreNamePrefix=$restoreNamePrefix-$(date '+%Y%m%d%H%M%S')
      if [ "$i" == "0" ] || [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
         printRestoreStatus
         restoreCommand="velero restore create $restoreNamePrefix --from-backup $backupName --include-namespaces $namespace -l $restoreLabel"
         $(echo $restoreCommand)
         # Wait for restore completion
         waitTillRestoreCompletion "$restoreNamePrefix"
      fi
   
   done
   restoreStatus=$(oc get restore $restoreName -n $veleronamespace -o=jsonpath='{.status.phase}')
   if [[ $restoreStatus == "Completed" ]]; then
        echo "Velero restore has finsihed with status $restoreStatus!"
   else
        echo "Velero restore has failed with status $restoreStatus! hence terminating the restore flow"
        exit 1
   fi
}

# This function is to wait till the completion of a job
waitTillJobCompletion() {
   jobName=$1
   namespace=$2
   echo $jobName $namespace
   wait "10"
   jobStatus=$(oc get job $jobName -n $namespace --no-headers | cut -d " " -f 4)
   echo Initial job status is: $jobStatus | tee -a "$log_file"
   
   while [ "$jobStatus" == "0/1" ] || [ "$jobStatus" == "0/0" ]
   do
     echo "Waiting for 1 min" | tee -a "$log_file"
     wait "30"
     jobStatus=$(oc get job $jobName -n $namespace --no-headers | cut -d " " -f 4)
     echo Job status is: $jobStatus | tee -a "$log_file"
   done
}
