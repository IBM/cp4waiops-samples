#!/bin/bash

#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================
echo "[INFO] $(date) ############## Connection CR restore started ##############"

source $WORKDIR/restore/restore-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

connectionCrRestoreNamePrefix="connection-cr-restore"
connectionCrRestoreLabel="connector.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, connectionCrRestoreNamePrefix: $connectionCrRestoreNamePrefix, connectionCrRestoreLabel: $connectionCrRestoreLabel"

echo "[INFO] $(date) Performing velero restore for connection cr's"
performVeleroRestore $connectionCrRestoreNamePrefix $backupName $namespace $connectionCrRestoreLabel
restoreRetVal=$?
echo "Velero restore return value is $restoreRetVal"
if [ $restoreRetVal -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence exiting...."
      exit 1
fi
echo "[INFO] $(date) ############## Connection CR restore completed ##############"

