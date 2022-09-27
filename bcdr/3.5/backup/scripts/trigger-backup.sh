#!/bin/bash

backup_name_suffix=$(cat $WORKDIR/common/aiops-config.json | jq -r '.backupNameSuffix')

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
