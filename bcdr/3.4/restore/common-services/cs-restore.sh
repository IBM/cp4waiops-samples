#!/bin/bash

#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================

source ../restore-utils.sh
source ../../common/prereq-check.sh
source ../../common/common-utils.sh


namespace=$(cat ../../common/aiops-config.json | jq -r '.csNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

#Reading couchdb restore info from config file
csRestoreNamePrefix="cs-restore"
csRestoreLabel="bedrock.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $csRestoreNamePrefix $csRestoreLabel

# Deleting old restored resources if exist
oc delete -f mongo-restore-dbdump.yaml -n $namespace 2> /dev/null
oc delete po dummy-db -n $namespace 2> /dev/null
oc delete pvc my-mongodump -n $namespace 2> /dev/null
oc delete cm cs-bcdr-config -n $namespace 2> /dev/null

# Performing velero restore for common services
performVeleroRestore $csRestoreNamePrefix $backupName $namespace $csRestoreLabel

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "my-mongodump"

# Delete dummy-pod since it's work is to only pull data into pvc
oc delete po dummy-db -n $namespace

# Deleting .velero directory from /dump location
oc create -f cleanup-pod.yaml -n $namespace
checkResourceReadyness "$namespace" "app=cleanup-pod" "40" "pod"
oc delete po cleanup-pod -n $namespace

# Setting mongo dump image value in restore job
mongodb_dump_image=$(oc get cm cs-bcdr-config -n ibm-common-services -o jsonpath='{.data.mongoDumpImage}')
sed -i "s~MONGODB_DUMP_IMAGE~$mongodb_dump_image~g" mongo-restore-dbdump.yaml

# Running mongo restore job
oc create -f mongo-restore-dbdump.yaml -n $namespace
oc get job icp-mongodb-restore -n $namespace
op=$(echo $?)
 
if [[ "$op" -eq 0 ]]; then
   echo "ICP mongodb restore job created"
else
   echo "ICP mongodb restore job not created hence not executing further restore steps"
   exit 1
fi

waitTillJobCompletion "icp-mongodb-restore" $namespace

# Deleting restored resources
oc delete job icp-mongodb-restore -n $namespace
oc delete pvc my-mongodump -n $namespace
oc delete cm cs-bcdr-config -n $namespace

echo "Common services mongodb restore is completed"
