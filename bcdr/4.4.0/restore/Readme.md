© Copyright IBM Corp. 2021, 2024

# Restoring the IBM Cloud Pak® for AIOps

Follow the steps to restore IBM Cloud Pak® for AIOps(CP4AIOPS).

## Before you begin
### Enable restore on your cluster
- Install Velero on your cluster, including the configuration of backup storage location.  See [../install/Readme.md](../install/Readme.md)

### Prepare your workstation to run the restore
- Workstation machine must have Linux base operating system and access to the internet. 
- To run and monitor the restore from a workstation, ensure the workstation has access to the cluster
- Install `velero`, `oc`, `jq`, `git` and `Helm` CLIs on your workstation 

### Check the backup status

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

## Procedure

### 1. Clone the GitHub repository

```
git clone https://github.ibm.com/katamari/bcdr.git
```

### 2. Log in to the OpenShift cluster

```
kubectl login --token=<TOKEN> --server=<URL>
```

Where:
   
 - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
 - `<URL>` is the OpenShift server URL.

### 3. Build the Docker image

**Note: Docker image creation step can be skipped if image is already created during backup process**

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr` by running the following command:

     ```
     cd <Path of cp4waiops-bcdr>/bcdr
     ```

  2. Build the `cp4waiops-bcdr` docker image by running following command:

      ```
      docker build -t cp4waiops-bcdr:latest .
      ```
      
### 4. Tag and push the Docker image to the image registry

```
docker tag cp4waiops-bcdr:latest <Image Registry Server URL>/<Repository>/cp4waiops-bcdr:latest
```

```
docker login <Image Registry Server URL> -u <USERNAME>
```

```
docker push <Image Registry Server URL>/<Repository>/cp4waiops-bcdr:latest
```

Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<Repository>` is the repository where you put the image.
   - `<USERNAME>` is the username to log in to the image registry server.

**Note:** User can use any image registry server like `quay.io` or `Docker Registry` or any other private image registry to keep the bcdr image, we don't have preference for any specific registry. Only thing is user should have image pull and push access to that image registry server and the image repository should be accessible to the cluster where backup and restores are expected to be perfomed.
 
 
### 5. Create an image pull secret by running the following command:

   ```
   kubectl create secret docker-registry restore-secret -n velero --docker-server=<Image Registry Server URL> --docker-username=<USERNAME> --docker-password=<PASSWORD> --docker-email=<EMAIL>
   ```

   Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<USERNAME>` is the username to log in to the image registry server.
   - `<PASSWORD>` is the password to log in to the image registry server.
   - `<EMAIL>` is the email for image registry server. 


### 6. Package the Helm Chart

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:

     ```
     cd <Path of cp4waiops-bcdr>/bcdr/restore
     ```

  2. Update the following parameters in `values.yaml`, `values.yaml` is located in `./helm`:

     - `backupName`: Name of the backup from which restoration needs to be done.
     - `aiopsNamespace`: Name of the namespace/project where `CP4WAIOPS` is installed in OpenShift source cluster. For example `cp4waiops`.
     - `csNamespace`: Name of the namespace/project where `IBM Common Services` is installed in OpenShift source cluster. For example `ibm-common-services`
     - `veleroNamespace`:  Name of the namespace/project where `Velero` is installed in OpenShift source cluster. For example `velero`

      
   3. Package the Helm Chart.

      ```
      helm package ./helm
      ```
  
### 7. Install the Helm Chart for restore

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:

     ```
     cd <Path of cp4waiops-bcdr>/bcdr/restore
     ```

  2. Deploy the backup job by running the following command:

     ```
     helm install restore-job clusterrestore-0.1.0.tgz
     ```

### 8. Update the image in ns-restore-job.yaml, aiops-restore-job.yaml and ia-restore-job.yaml
  
  1. Need to update the image namein each yaml file for restore-job. This image is same which is created in step no.4 `<Image Registry Server URL>/<Repository>/cp4waiops-bcdr:latest`.
  - `ns-restore-job.yaml`: For restoring the namespaces
  - `aiops-restore-job.yaml`: For restoring the CP4WAIOPS
  - `ia-restore-job.yaml`: For restoring the Infrastruuctire Automation
  
  2. Update the `JOB_NAME` also in these files with respect to their corresponding restore nature.
     For an example, `JOB_NAME` in ns-restore-job.yaml should be as `ns-restore-job` and `aiops-restore-job` in `aiops-restore-job.yaml` yaml file.


### 9. Deploy the restore Job to restore namespace

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:
   
     ```
     cd <Path of cp4waiops-bcdr>/bcdr/restore
     ```
     
  2. Delete the previously existing namespace restore job if created.

     ```
     kubectl delete -f ns-restore-job.yaml
     ```
  
  3. Create a job to restore namespace.

     ```
     kubectl create -f ns-restore-job.yaml
     ```

  4. Check the restore job logs by running the following command:

     ```
     kubectl logs -f <ns-restore-job-***>
     ```

   5. Check the velero-restore status for namespace by running the following command:
 
      ```
      velero get restore <RESTORE_NAME>
      ```

      Where:

      - `<RESTORE_NAME>` is the name of the restore for namespace. You can see the this restore name after the restore job is completed. For example, you might see the restore name `cs-namespace-restore-20221006054710` and `aiops-namespace-restore-20221006054710` in the restore job log as follows:
        
        ```
        Restore request "cs-namespace-restore-20221006054710" submitted successfully.
        ```
        and
        
        ```
        Restore request "aiops-namespace-restore-20221006054710" submitted successfully.
        ```
        
### 10. Install the CP4WAIOPS and Infrastructure Automation

  1. If aiops restore is required, then install CP4WAIOps operator and create an AI Manager instance.
  
  2. If Infrastructure Automation restore is required, then install Infrastructure Automation operator and create IAConfig CR. Expectation is after creating IAConfig CR, Managed Services operator will be installed and it's CR will be created automatically. And for Infrastructure management only operator install will be done and no CR creation is required as it will be done through restore process.


### 11. Deploy the restore Job to restore CP4WAIOPS

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:
  
     ```
     cd <Path of cp4waiops-bcdr>/bcdr/restore
     ```
  
  2. Delete the previously existing aiops restore job if created.

     ```
     kubectl delete -f aiops-restore-job.yaml
     ```
  
  3. Create a job to restore CP4WAIOPS.

     ```
     kubectl create -f aiops-restore-job.yaml
     ```

  4. Check the restore job logs by running the following command:

     ```
     kubectl logs -f <aiops-restore-job-***>
     ```

   5. Check the velero-restore status for CP4WAIOPS by running the following command:
 
      ```
      velero get restore <RESTORE_NAME>
      ```

      Where:

      - `<RESTORE_NAME>` is the name of one of the the restores for CP4WAIOPS componenets. You can see the these restore names after the restore job is completed. For example, you might see the restore name `cassandra-restore-20221006054710` for Cassandra restore in the restore job log as follows:
        
        ```
        Restore request "cassandra-restore-20221006054710" submitted successfully.
        ```
        
        Similarly, there will be velero restore name for other CP4WAIOPS componenets in the restore job log and those can also be checked.


### 12. Deploy the restore Job to restore Infrastructure Automation

**Note: If restoring in the cluster where IM already exists, make sure IMInstall CR is deleted before attempting restore**

- For restoring IM, configure LDAP and ensure that LDAP group name is the same as the one that is defined in the backed-up Infrastructure Management CR


1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:
  
   ```
   cd <Path of cp4waiops-bcdr>/bcdr/restore
   ```

2. Delete the previously existing ia restore job if created.

     ```
     kubectl delete -f ia-restore-job.yaml
     ```

3. Create a job to restore namespace.

   ```
   kubectl create -f ia-restore-job.yaml
   ```

 4. Check the restore job logs by running the following command:

   ```
   kubectl logs -f <ia-restore-job-***>
   ```

 5. Check the velero-restore status for namespace by running the following command:
 
    ```
    velero get restore <RESTORE_NAME>
    ```

    Where:

    - `<RESTORE_NAME>` is the name of the restore for IA componenets. You can see the these restore names after the restore job is completed. For example, you might see the restore name `cam-restore-20221006054710` for CAM restore  and `im-restore-20221006054710` for Infrastructure Management in the restore job log as follows:
        
      ```
      Restore request "cam-restore-20221006054710" submitted successfully.
      ```
        
      Similarly, there will be velero restore name for IM in the restore job log and that can also bechecked.
        
 5. Restart the `zen-watcher` pod once IM restore has completed and all the infrastructure-management pods are in running state

    `kubectl delete pod -l app.kubernetes.io/component=zen-watcher -n <infrastructure management namespace>`

### 13. [Optional] Deploy the restore Job to restore individual CP4WAIOPS component if there is a requiremnent to rerun the restore for any DB/component after CP4WAIOPS restore step

 1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/restore` by running the following command:
  
     ```
     cd <Path of cp4waiops-bcdr>/bcdr/restore
     ```
 
  2. Copy the aiops-restore-job.yaml to `<cp4waiops-component>-restore-job.yaml`.
     Here, `<cp4waiops-component>` is the name of cp4waiops component to be restored, e.g. cassandra-restore-job.yaml.
 
  3. Update the `name` and `command` sections in `<cp4waiops-component>-restore-job.yaml`

     1. Update the `name` of restore job in metedata section of `<cp4waiops-component>-restore-job.yaml` for individual cp4waiops component, e.g. `cassandra-restore-job` 
     2. Update the command section `command: ["/bin/bash", "restore.sh","-aiops"]` in `<cp4waiops-component>-restore-job.yaml`.
     You need to replace `-aiops` with respective available option for individual cp4waiops DB/component `<cp4waiops-component-argument>`.
     
     Here, following are  the supported options to restore individual cp4waiops component. 
     
     |DB/Components to be restored | cp4waiops-component-argument |
     | ------------ | -------------- |
     |Cassandra	   | -cassandra
     |CS	           | -cs
     |CouchDb	   | -couchdb
     |Elasticsearch | -es
     |Metastore	   | -metastore
     |Minio	       | -minio
     |Postgres      | -postgres
     |Vault	       | -vault
     |Connection CR | -connectioncr
     |Tunnel CR	   | -tunnelcr
     |CAM	       | -cam
     |Infrastructure Management	| -im
 
  4. Create a job to restore individual CP4WAIOPS DB/component.

     ```
     kubectl create -f <cp4waiops-component>-restore-job.yaml
     ```

  5. Check the restore job logs by running the following command:

     ```
     kubectl logs -f <cp4waiops-component-restore-job-***>
     ```

   6. Check the velero-restore status for CP4WAIOPS individual component by running the following command:
 
      ```
      velero get restore <RESTORE_NAME>
      ```

      Where:

      - `<RESTORE_NAME>` is the name of one of the the restores for CP4WAIOPS componenet. You can see the these restore names after the restore job is completed. For example, you might see the restore name `cassandra-restore-20221006054710` for Cassandra restore in the restore job log as follows:
        
        ```
        Restore request "cassandra-restore-20221006054710" submitted successfully.
        ```
        
        
## Troubleshooting

### 1. Velero restore is getting stuck in `In progress` state for long time.

Perform following steps to terminate the backup process :

1. Delete the velero pod.
   
   `kubectl delete pod <velero pod name> -n <velero installed namespace>`

2. Delete the restore which got stucked in `In progress` state.

   `velero delete restore <restore name>`

3. Wait till completion of respective restore job.


### 2. Command `helm install restore-job clusterrestore-0.1.0.tgz` failed with the following error:

```
Error: admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request:
Deny "<Image Registry Server URL>/<Repository>/cp4waiops-bcdr:latest", no matching repositories in ClusterImagePolicy and no ImagePolicies in the "velero" namespace
```

Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<Repository>` is the repository where you put the image.

As a fix perform the following steps:
   
   1. Uninstall `restore-job` by running the following command:

      ```
      helm uninstall restore-job -n velero
      ```

   2. Create a file `backup-image-policy.yaml` and add the following content to it:
   
      ```
      apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
      kind: ClusterImagePolicy
      metadata:
        name: restore-image-policy
      spec:
       repositories:
        - name: "<Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest"
          policy:
      ```
   
   3. Apply the policy by running the following command:
   
      ```
      kubectl apply -f restore-image-policy.yaml
      ```

   4. Deploy the restore Helm Chart by running the following command:

      ```
      helm install restore-job clusterrestore-0.1.0.tgz
      
### 3. LDAP user login is not working after restore.

Perform the following steps for LDAP user to login after restore:

1. Login to the CP4WAIOPS console using default admin credentials.
2. From the navigation menu, select **Administration > Access control > Identity provider configuration**.
3. Select the ldap connection and click **Edit connection**.
4. Click **Test connection**.
5. Click **Save** once the connection is success.
You can now retry to login using the ldap credentials.

### 4. Cleanup steps for DBs/components if respective restore job execution gets aborted/terminated in mid of execution.

Execute respective post-restore script if respective restore job execution gets aborted in mid of execution and we need to perform restore again for respective component.

Example, If Cassandra restore-script gets aborted in mid of execution, then please go to path `bcdr/restore/cassandra` and execute `cassandra-post-restore.sh` and then `cassandra-native-post-restore.sh`

#### Prereq steps for running the clean up scripts.
 1. Define environment variable on your work station.
    
    `export WORKDIR="<Path of cp4waiops-bcdr>/bcdr"
 2. Update the `aiopsNamespace`, `csNamespace` and `veleroNamespace` in `<Path of cp4waiops-bcdr>/bcdr/common/aiops-config.json
 3. Update the backup name in `<Path of cp4waiops-bcdr>/bcdr/restore/restore-data.json`

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

### 5. CAM restore fails and cam-mongo pod goes into error state.

Sometimes due to issues like storage quota on restore/target cluster momentarily, CAM restore may get failed and we need to rerun CAM restore to overcome such issue.

1. Define environment variable on your work station.
    
    `export WORKDIR="<Path of cp4waiops-bcdr>/bcdr"`
    
2. Update the `aiopsNamespace`, `csNamespace` and `veleroNamespace` in `<Path of cp4waiops-bcdr>/bcdr/common/aiops-config.json
3. Update the backup name in `<Path of cp4waiops-bcdr>/bcdr/restore/restore-data.json`
4. Execute restore script (from bcdr/restore/cam)

  `nohup ./cam-restore.sh > cam-restore.log &`

### 6. CAM service deployment fails for socket hang up after managed services (CAM) restore.

Sometimes, after CAM restore when service is deployed then it's instance fails due to socket hang up issue. In this case `cam-iaas` pod should be restarted.

`kubectl delete pod <cam-iaas-xxxx> -n <iaNamespace>`

