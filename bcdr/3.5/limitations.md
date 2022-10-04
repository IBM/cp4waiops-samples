## Limitations and issues

### For details about troubleshooting please refer to
#### Install
- https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.5.0?topic=manager-installing-backup-restore-tools-online
    - Velero backups are not showing after installation

#### Backup
- https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.5.0?topic=manager-backing-up-ai
    - Velero backups are stuck in the In progress state
    - Classifier and layout pods remain not ready after running a backup
    - Helm install backup job command failed

#### Restore
- https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.5.0?topic=manager-restoring-ai
    - Restore process for ElasticSearch failed
    - LDAP user login is not working after restoration
    - Data is not being processed after restoration
    - Change risk assessments are not processed
    - Topology observer jobs do not run after restore
    - Restore process terminated mid-process with partial data available
    - Troubleshooting the Infrastructure Automation restore