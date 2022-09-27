## Before you begin
- Update `bcdr/common/aiops-config.json` file with actual aiops, common services and velero namespace
- Update `bcdr/restore/restore-data.json` file with the backup name from which restoration needs to be done
- You need to install the oc, velero, jq, git and docker CLIs on a workstation machine where you can access the OpenShift cluster, initiate, and monitor the restoration of CP4WAIOps.
- All required storage classes must be created prior to the restore and storage classes must have the same name as the backup cluster.

## Initial tasks
- Create a new cluster
- Install OADP/Velero pointing to same the S3 bucket location containing the backup
- Restore common services and aiops\ia namespaces. 
This step only creates the namespaces and namespace metadata but does NOT restore the contents of the namespace. This is important because the metadata contains SELinux settings that MUST match the settings from the corresponding namespaces on the cluster where you took the backup. 
Run the following commands to restore the namespaces. 
    - Execute namespace restore script (from bcdr/restore/other-resources)

        `nohup ./restore-namespace.sh > restore-namespace.log &`

    - Check the logs by running the following command
  
        `tail -f restore-namespace.log`
- If aiops restore is required, then install CP4WAIOps operator and create an AI Manager instance
- If Infrastructure Automation restore is required, then install Infrastructure Automation operator and create IAConfig CR. Expectation is after creating IAConfig CR, Managed Services operator will be installed and it's CR will be created automatically. And for Infrastructure management only operator install will be done and no CR creation is required as it will be done through restore process.

## Check the backup status

Ensure that the backup you took is complete by running the following:

 `velero describe backup <backup-name> --details`

 Output should be similar to:

  ```
   v1/PersistentVolumeClaim:
    - cp4waiops/back-aiops-topology-cassandra-0
    - cp4waiops/data-c-example-couchdbcluster-m-0
    - cp4waiops/export-aimanager-ibm-minio-0
    - cp4waiops/iaf-system-elasticsearch-es-snap-es-backup-pvc
    - cp4waiops/ibm-postgresql-action
    - cp4waiops/metastore-backup-data
    - ibm-common-services/my-mongodump
  v1/Pod:
    - cp4waiops/backup-back-aiops-topology-cassandra-0
    - cp4waiops/backup-data-c-example-couchdbcluster-m-0
    - cp4waiops/backup-export-aimanager-ibm-minio-0
    - cp4waiops/backup-metastore
    - cp4waiops/es-backup
    - cp4waiops/ibm-postgresql-action--1-tqmdf
    - ibm-common-services/dummy-db
  v1/Secret:
    - cp4waiops/aimanager-ibm-minio-access-secret
    - cp4waiops/aiops-ir-core-model-secret
    - ibm-common-services/icp-mongodb-admin
    - ibm-common-services/icp-serviceid-apikey-secret

    Velero-Native Snapshots: <none included>

  Restic Backups:
   Completed:
    cp4waiops/backup-back-aiops-topology-cassandra-0: backup
    cp4waiops/backup-data-c-example-couchdbcluster-m-0: backup
    cp4waiops/backup-export-aimanager-ibm-minio-0: backup
    cp4waiops/backup-metastore: data
    cp4waiops/es-backup: elasticsearch-backups
    cp4waiops/ibm-postgresql-action--1-tqmdf: backup
    ibm-common-services/dummy-db: mongodump

  ```

## Restore CP4WAIOps data and configuration
This is a multi-step process. Complete all the steps in the sections below.

### Basepak restore steps
  - These steps are required for both CP4WAIOPS and IA restore

#### Restore Common Services
  - Execute restore script (from bcdr/restore/common-services)

    `nohup ./cs-restore.sh > cs-restore.log &`

- Check the logs by running the following command
  
  `tail -f cs-restore.log`
  
#### Restore metastore

- Execute restore script (from bcdr/restore/metastore)

  `nohup ./metastore-restore.sh > metastore-restore.log &`

- Check the logs by running the following command
  
  `tail -f metastore-restore.log`

- Ensure all the aiops pods are in running state

- Done with metastore restore

### CP4WAIOPS restore steps
  - These steps are required for CP4WAIOPS restore

#### Restore CouchDB
- Run couchdb restore script (from bcdr/restore/couchdb)

  `nohup ./couchdb-restore.sh > couchdb-restore.log &`

- Check the logs by running the following command
  
  `tail -f couchdb-restore.log`

- Ensure all the aiops pods are in running state after restore

- Done with couchdb restore

### Restore Elastic Search
- Run the elasticsearch velero restore script (from bcdr/restore/elasticsearch)

  `nohup ./es-velero-restore.sh > es-velero-restore.log &`

- Check the logs by running the following command

  `tail -f es-velero-restore.log`

- Note: Elasticsearch pods may get restarted if the cluster has been previously configured for elasticsearch backup, wait till all the related pods(iaf-system-elasticsearch-es-aiops-XXX) are restarted

- Update backup path and snapshot location in automationbase CR by executing script

  `nohup ./automationbase-cr-update.sh > automationbase-cr-update.log &`

- Check the logs by running the following command

  `tail -f automationbase-cr-update.log`

- Wait till all the elasticsearch pods(iaf-system-elasticsearch-es-aiops-XXX) are restarted

- Run the elasticsearch restore script (from bcdr/restore/elasticsearch)

  `nohup ./es-restore.sh > es-restore.log &`

- Check the logs by running the following command

  `tail -f es-restore.log`

- Ensure all the aiops pods are in running state

- Done with elasticsearch restore

#### Restore Cassandra

- Run cassandra restore script (from bcdr/restore/cassandra)

  `nohup ./cassandra-restore.sh > cassandra-restore.log &`

- Check the logs by running the following command
  
  `tail -f cassandra-restore.log`

- Ensure all the aiops pods are in running state after restore

- Done with cassandra restore


**Note:**
- By default, restore will be performed from latest cassandra backup but if you want to restore a particular cassandra backup then you need to update file `bcdr/restore/cassandra/backup-timestamp.json` with required `backuptimestamp`and change the value for key `manualinput` to `true`. `backuptimestamp` value can be retrieved from restored backup tar file, for an axample if backup tar file name is `cassandra-0_KS_system_schema_KS_system_KS_tararam_KS_janusgraph_KS_mime_config_KS_system_auth_KS_aiops_policies_KS_system_distributed_KS_system_traces_KS_aiops_date_2022-05-30-1112-43.tar` then we extract timestamp value `2022-05-30-1112-43` from this file and update key `backuptimestamp` in `bcdr/restore/cassandra/backup-timestamp.json`

    Execute the following steps if you need to restore a particular backup for Cassandra
    - `oc exec -n <aiops namespace> aiops-topology-cassandra-0 -- ls -ltr /opt/ibm/cassandra/data/backup_tar`
    - Select the backup tar file from the list to restore, retrieve the timestamp value from the tar file and update the value for key `backuptimestamp` in file `bcdr/restore/cassandra/backup-timestamp.json`

#### Restore Minio
- Run minio restore script  (from bcdr/restore/minio)

  `nohup ./minio-restore.sh > minio-restore.log &`

- Check the logs by running the following command
  
  `tail -f minio-restore.log`

- Ensure all the aiops pods are in running state after restore

- Done with minio restore

#### Restore Postgres
- Run restore script (from bcdr/restore/postgres)

  `nohup ./edb-postgres-restore.sh > edb-postgres-restore.log &`

- Check the logs by running the following command
  
  `tail -f edb-postgres-restore.log`

- Ensure all the aiops pods are in running state

- Done with postgres restore

#### Restore additional CR's 
##### Connection CR
- Run restore script (from bcdr/restore/other-resources)

  `nohup ./connection-cr-restore.sh > connection-cr-restore.log &`

- Check the logs by running the following command

  `tail -f connection-cr-restore.log`

##### Tunnel CR
- Run restore script (from bcdr/restore/other-resources)

  `nohup ./tunnel-cr-restore.sh > tunnel-cr-restore.log &`

- Check the logs by running the following command

  `tail -f tunnel-cr-restore.log`

#### Restore vault

- Execute restore script (from bcdr/restore/vault)

  `nohup ./ibm-vault-restore.sh > ibm-vault-restore.log &`

- Check the logs by running the following command
  
  `tail -f ibm-vault-restore.log`

- Ensure all the aiops pods are in running state

- Done with vault restore

### IA restore steps
  - These steps are required for IA restore

#### Restore CAM

- Execute restore script (from bcdr/restore/cam)

  `nohup ./cam-restore.sh > cam-restore.log &`

- Check the logs by running the following command
  
  `tail -f cam-restore.log`

- Ensure all the aiops and cam pods are in running state

- Done with cam restore

#### Restore Infrastructure Management

**Note: If restoring in the cluster where IM already exists, make sure IMInstall CR is deleted before attempting restore**

- Configure LDAP, and ensure that LDAP group name is the same as the one that is defined in the backed-up Infrastructure Management CR

- Execute restore script (from bcdr/restore/infrastructure-management)

  `nohup ./im-restore.sh > im-restore.log &`

- Check the logs by running the following command
  
  `tail -f im-restore.log`

- Wait till all the aiops and infrastructure management pods are in running state
- Restart the `zen-watcher` pod

  `oc delete pod -l app.kubernetes.io/component=zen-watcher -n <infrastructure management namespace>`

- Done with infrastructure management restore


## Troubleshooting

### 1. LDAP user login is not working after restore.

Perform the following steps for LDAP user to login after restore:

1. Login to the CP4WAIOPS console using default admin credentials.
2. From the navigation menu, select **Administration > Access control > Identity provider configuration**.
3. Select the ldap connection and click **Edit connection**.
4. Click **Test connection**.
5. Click **Save** once the connection is success.
You can now retry to login using the ldap credentials.

### 2. Cleanup steps for DBs/components if respective restore script execution gets aborted/terminated in mid of execution.

Execute respective post-restore script if respective restore script execution gets aborted in mid of execution and we need to perform restore again for respective DB/component.

Example, If Cassandra restore-script gets aborted in mid of execution, then please go to path `bcdr/restore/cassandra` and execute `cassandra-post-restore.sh` and then `cassandra-native-post-restore.sh`

|DB/Components | Cleanup script |
| ------------ | -------------- |
|Cassandra	   |bcdr/restore/cassandra/cassandra-post-restore.sh and then bcdr/restore/cassandra/cassandra-native-post-restore.sh
|CS	           |bcdr/restore/common-services/cs-post-restore.sh
|CouchDb	   |bcdr/restore/couchdb/couchdb-post-restore.sh
|Elasticsearch |bcdr/restore/elasticsearch/es-post-restore.sh
|Metastore	   |bcdr/restore/metastore/metastore-post-restore.sh
|Minio	       |bcdr/restore/minio/minio-post-restore.sh
|Postgres      |bcdr/restore/postgres/postgres-post-restore.sh
|Vault	       |bcdr/restore/vault/ibm-vault-post-restore.sh
|Connection CR |N/A
|Tunnel CR	   |bcdr/restore/other-resources/tunnel-cr-post-restore.sh
|CAM	       |bcdr/restore/cam/cam-post-restore.sh
|Infrastructure Management	| bcdr/restore/infrastructure-management/im-cleanup-restore.sh


