#!/bin/bash
echo "[INFO] $(date) ############## Vault restore started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source ../restore-utils.sh
source ../../common/common-utils.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
backupName=$(cat ../restore-data.json | jq -r '.backupName')
vaultRestoreNamePrefix="vault-restore"
vaultRestoreLabel="otherresources.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, vaultRestoreNamePrefix: $vaultRestoreNamePrefix, vaultRestoreLabel: $vaultRestoreLabel"

echo "[WARNING] $(date) Deleting old other resources backup pod and pvc if any"
oc delete pod backup-other-resources -n $namespace 2> /dev/null  
oc delete pvc other-resources-backup-data -n $namespace 2> /dev/null

echo "[INFO] $(date) Performing velero restore for tunnel cr's"
performVeleroRestore $vaultRestoreNamePrefix $backupName $namespace $vaultRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      ./ibm-vault-post-restore.sh
      exit 1
fi

# Move the ibm-vault-deploy-backup folder outside of backup-other-resources pod
{  # try
   oc cp -n $namespace backup-other-resources:/usr/share/backup/ibm-vault-deploy-backup ./ibm-vault-deploy-backup &&
   echo "[INFO] $(date) ibm-vault-deploy-backup folder transferred to outside of backup-other-resources pod!" 
} || { # catch
   echo "[ERROR] $(date) Transfer of ibm-vault-deploy-backup folder to outside of backup-other-resources pod failed, hence exiting!"
}

# Running vault restore script
./native-vault-restore.sh -n $namespace

./ibm-vault-post-restore.sh

echo "[INFO] $(date) ############## Vault restore completed ##############"
