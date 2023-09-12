#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================

source ../restore-utils.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

connectionCrRestoreNamePrefix="connection-cr-restore"
connectionCrRestoreLabel="connector.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $connectionCrRestoreNamePrefix $connectionCrRestoreLabel

# Performing velero restore for connection cr's
performVeleroRestore $connectionCrRestoreNamePrefix $backupName $namespace $connectionCrRestoreLabel

echo "Connection cr restore is completed"

