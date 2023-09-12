#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#
echo "[INFO] $(date) ############## Vault backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/common-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

vaultBackup="false"

# Deleting previous backup folder if exists
rm -rf ibm-vault-deploy-backup

# Running vault backup script
./native-vault-backup.sh -n $namespace

# Move the ibm-vault-deploy-backup folder to backup-other-resources pod
{  # try
   oc cp -n $namespace ibm-vault-deploy-backup backup-other-resources:/usr/share/backup/ibm-vault-deploy-backup &&
   echo "[INFO] $(date) ibm-vault-deploy-backup folder transferred to pod backup-other-resources!" &&
   vaultBackup="true"
} || { # catch
   echo "[ERROR] $(date) Transfer of ibm-vault-deploy-backup folder to backup-other-resources pod failed, hence exiting!"
   rm -rf ibm-vault-deploy-backup
}

# Deleting ibm-vault-deploy-backup folder
rm -rf ibm-vault-deploy-backup

# Updating the backup result for IBM vault
if [[ $vaultBackup == "true" ]]; then
   jq '.ibmVaultBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

echo "[INFO] $(date) ############## Vault backup completed ##############"
