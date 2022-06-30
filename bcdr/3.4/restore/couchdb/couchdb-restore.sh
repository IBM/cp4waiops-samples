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
source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

#Reading couchdb restore info from config file
couchDbRestoreNamePrefix="couchdb-restore"
couchDbRestoreLabel="couchdb.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $couchDbRestoreNamePrefix $couchDbRestoreLabel

# Executing couchdb pre restore tasks
./couchdb-pre-restore.sh

# Performing velero restore for couchdb
performVeleroRestore $couchDbRestoreNamePrefix $backupName $namespace $couchDbRestoreLabel

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "data-c-example-couchdbcluster-m-"

# Executing couchdb post restore tasks
./couchdb-post-restore.sh

# Wait till couchdb and rba pods are ready
checkPodReadyness $namespace "app.kubernetes.io/component=rba-as" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=rba-rbs" "60"
#checkPodReadyness $namespace "app.kubernetes.io/instance=example-couchdbcluster" "60"

echo "Couchdb restore is completed"