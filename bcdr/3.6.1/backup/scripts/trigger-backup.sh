#!/bin/bash

backup_name_suffix_original=$(cat $WORKDIR/common/aiops-config.json | jq -r '.backupNameSuffix')
echo "[DEBUG] $(date) Original backup name suffix value is $backup_name_suffix_original"

# Converting backup_name_suffix_original to lowercase
backup_name_suffix=$(echo "$backup_name_suffix_original" | tr '[:upper:]' '[:lower:]')
echo "[DEBUG] $(date) After converting to lower case backup name suffix value is $backup_name_suffix"

TriggerBackup() {

  # Remove the backup.yaml file
  rm -f backup.yaml

  # Copy and Rename backup file
  cp /workdir/backup_original.yaml backup.yaml

  # Generate unique name
  BACKUP_NAME=$(echo "aiops-backup-$(date +%s)-$backup_name_suffix")

  # Replace BACKUP-NAME with unique name
  sed -i 's/BACKUP-NAME/'$(echo $BACKUP_NAME)'/' backup.yaml

  # Execute command
  oc create -f backup.yaml
}

# Trigger Backup
TriggerBackup
