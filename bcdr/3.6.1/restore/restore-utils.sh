#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================

CURRENT=$(pwd)
log_file="$CURRENT/restore.log"

source $WORKDIR/common/common-utils.sh
veleronamespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.veleroNamespace')

echo "=============================================" | tee -a "$log_file"

# This functio is to print restore status message
printRestoreStatus() {
   if [[ "$restoreStatus" == 'PartiallyFailed' ]]; then
      echo "[WARNING] $(date) Restore is PartiallyFailed hence retrying the restore again"
   elif [[ "$restoreStatus" == 'Completed' ]]; then
      echo "[INFO] $(date) Restore is Completed"
   elif [[ "$restoreStatus" == '' ]]; then
      echo ""
   else
      echo "[INFO] $(date) Restore status is: $restoreStatus"
   fi
}

# This function is to check whether backup exists or not, it accepts one positional argument i.e backupName
checkBackup() {
   echo "[INFO] $(date) Backup name is $backupName"
   backupCheckValue=0
   velero get backup $backupName
   if [ $? -eq 0 ]; then
      echo "[INFO] $(date) Backup exists" | tee -a "$log_file"
   else
      echo "[ERROR] $(date) Backup not found hence terminating restore process" | tee -a "$log_file"
      backupCheckValue=1
      #exit 1
   fi
}

# This function is to check the restore status periodically till it completes, it accepts one positional argument i.e restoreName
waitTillRestoreCompletion() {
   restoreName=$1
   echo "[INFO] $(date) Restore name passed to func waitTillRestoreCompletion is: $restoreName" | tee -a "$log_file"
   wait "10"
   restoreStatus=$(oc get restore $restoreName -n $veleronamespace -o=jsonpath='{.status.phase}')
   echo "[INFO] $(date) Initial velero restore status is: $restoreStatus" | tee -a "$log_file"
   
   while [ "$restoreStatus" == "InProgress" ] || [ "$restoreStatus" == "New" ]
   do
     echo "[INFO] $(date) Waiting for 1 min" | tee -a "$log_file"
     wait "60"
     restoreStatus=$(oc get restore $restoreName -n $veleronamespace -o=jsonpath='{.status.phase}')
     echo "[INFO] $(date) Velero restore status is: $restoreStatus" | tee -a "$log_file"
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
      echo "[INFO] $(date) Restore exists"
   else
      isRestoreExists="false"
      echo "[WARNING] $(date) Restore does not exist"
   fi
}

# This function is to perform restore
performVeleroRestore() {
   restoreNamePrefix=$1
   backupName=$2
   namespace=$3
   restoreLabel=$4
   restoreCheckValue=0
   checkBackup "$backupName"
   if [ $backupCheckValue -ne 0 ]; then
      echo "[ERROR] $(date) Check Backup failed"
      return $backupCheckValue
   fi
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
        echo "[INFO] $(date) Velero restore has finsihed with status $restoreStatus!"
	echo "[INFO] $(date) #########Velero restore details#########"
	velero describe restore $restoreName --details
	return $restoreCheckValue
   else
        echo "[ERROR] $(date) Velero restore has failed with status $restoreStatus! Hence terminating the restore flow"
	#exit 1
	echo "[INFO] $(date) #########Velero restore details#########"
	velero describe restore $restoreName --details
	restoreCheckValue=1
	return $restoreCheckValue
   fi
}

# This function is to wait till the completion of a job
waitTillJobCompletion() {
   jobName=$1
   namespace=$2
   echo "[INFO] $(date) jobName: $jobName, namespace: $namespace"
   wait "10"
   jobStatus=$(oc get job $jobName -n $namespace --no-headers | cut -d " " -f 4)
   echo "[INFO] $(date) Initial job status is: $jobStatus" | tee -a "$log_file"
   
   while [ "$jobStatus" == "0/1" ] || [ "$jobStatus" == "0/0" ]
   do
     echo "[INFO] $(date) Waiting for 1 min" | tee -a "$log_file"
     wait "30"
     jobStatus=$(oc get job $jobName -n $namespace --no-headers | cut -d " " -f 4)
     echo "[INFO] $(date) Job status is: $jobStatus" | tee -a "$log_file"
   done
}
