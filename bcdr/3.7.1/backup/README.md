© Copyright IBM Corp. 2021, 2023

# Backing up IBM Cloud Pak® for Watson AIOps

Follow the steps to back up IBM Cloud Pak® for Watson AIOps(CP4WAIOPS).

## Before you begin
### Enable backup on your cluster
- Install Velero on your cluster, including the configuration of backup storage location.  See [../install/Readme.md](../install/Readme.md)

### Prepare your workstation to run the backup
- Workstation machine must have Linux base operating system and access to the internet. 
- To run and monitor the backup from a workstation, ensure the workstation has access to the cluster
- Install `velero`, `oc`, `jq`, `git` and `Helm` CLIs on your workstation 


## Procedure

### 1. Clone the GitHub repository

```
git clone https://github.ibm.com/katamari/bcdr.git
```

### 2. Log in to the OpenShift cluster

```
oc login --token=<TOKEN> --server=<URL>
```

Where:
   
 - `<TOKEN>` is the token that you use to log in to the OpenShift cluster.
 - `<URL>` is the OpenShift server URL.



### 3. Build the Docker image

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
   oc create secret docker-registry backup-secret -n velero --docker-server=<Image Registry Server URL> --docker-username=<USERNAME> --docker-password=<PASSWORD> --docker-email=<EMAIL>
   ```

   Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<USERNAME>` is the username to log in to the image registry server.
   - `<PASSWORD>` is the password to log in to the image registry server.
   - `<EMAIL>` is the email for image registry server. 

### 6. Package the Helm Chart

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/backup` by running the following command:

     ```
     cd <Path of cp4waiops-bcdr>/bcdr/backup
     ```

  2. Update the following parameters in `values.yaml`, `values.yaml` is located in `./helm`:

     - `repository`: Name of the image for example `xy.abc.io/cp4waiops/cp4waiops-bcdr`. Here `xy.abc.io` is the image registry server URL, `cp4waiops` is the name of the repository and `cp4waiops-bcdr` is the name of the Docker image.
     - `pullPolicy`: Policy to determine when to pull the image from the image registry server. For example, To force pull the image, use the `Always` policy. 
     - `tag`: Tag of the Docker image for example `latest`.
     - `pullSecret`: Name of the image pull secret. Refer to the value from step 6.
     - `schedule`: Cron expression for automated backup. For example, To take backup once a day, use the `0 0 * * *` Cron expression.
     - `backupStorageLocation`: This is `velero` storage location where backed up data are stored. For example `bcdr-s3-location`.  Use the `oc get backupstoragelocation -n <velero-namespace>` command to get the backupStorageLocation on the OpenShift cluster.
     - `backupNameSuffix`: This is the prefix for the backup name when backup is created using job. Generally, it can be name of source cluster itself. For example `aiops-cluster-backup-106`.
     - `aiopsNamespace`: Name of the namespace/project where `CP4WAIOPS` is installed in OpenShift source cluster. For example `cp4waiops`.
     - `csNamespace`: Name of the namespace/project where `IBM Common Services` is installed in OpenShift source cluster. For example `ibm-common-services`
     - `veleroNamespace`:  Name of the namespace/project where `Velero` is installed in OpenShift source cluster. For example `velero`
     - `ttl`: Time to live for backup. It means backup data will be retained until TTL expires. For example `720h0m0s`
     - `enabledNamespaces`: Lists the namespaces that are associated for installed components. For example, the `ibm-common-services` namespace represents the `IBM Common Services` component. You can delete the unused namespaces from the list to reduce the time taken for back up. You can update the list as shown if you have installed only two components, i.e. `IBM Common Services` and `CP4WAIOPS`
     
       ```
       enabledNamespaces:
       - '"ibm-common-services"'
       - '"cp4waiops"'
       ``` 

       The following table lists the components and namespaces as an example:

       | Components    | Namespaces |
       | ------------- |-------------|
       | IBM Common Services      | ibm-common-services |
       | IBM Cloud Pak® for Watson AIOps      | cp4waiops      |

     - `enabledComponents`: Backup & Restore of AIOPs now supports backing and restoring of AIOPs as well as IA (Infrastructure Automation) components. Since IA is optional component and it can be installed indepenently of AIOPs and vice versa. A new `enabledComponents` parameter is intorduced, this is passed as the List of the component to be backed up.  Currently following two values are supported `IA` and `AIOPS`. This is mandatory parameter and expects one of the two or both are expected, any other values will be ignored and corresponding error message will generated.
     
       ```
       enabledComponents:
       - '"IA"'
       - '"AIOPS"'
       ``` 
      
   3. Package the Helm Chart.

      ```
      helm package ./helm
      ```
      
### 7. Trigger an automated backup

  1. Go to the directory `<Path of cp4waiops-bcdr>/bcdr/backup` by running the following command:

     ```
     cd <Path of cp4waiops-bcdr>/bcdr/backup
     ```

  2. Deploy the backup job by running the following command:

     ```
     helm install backup-job clusterbackup-0.1.0.tgz

### 8. Monitor the backup Job

  1. Check the backup pods status by running the following command:

     ```
     oc get pods -n velero
     ```

  2. Check the backup job logs by running the following command:

     ```
     oc logs -f <backup-job-***>
     ```

   3. Check the backup status by running the following command:
 
      ```
      velero get backup <BACKUP_NAME>
      ```

      Where:

      - `<BACKUP_NAME>` is the name of the Backup. You can see the backup name after the backup job is complete. For example, you might see the backup name `aiops-cluster-backup-106-1622193915` in the backup job log as follows:
        
        ```
        Waiting for backup aiops-cluster-backup-106-1622193915 to complete
        ```
### 10. Trigger an on-demand backup

  1. Deploy the on-demand backup job by running the following command: 
    
     ```
     oc create job --from=cronjob/backup-job on-demand-backup-job -n velero
      ```
     - This step is optional. Use only when you don't want to wait till the execution of the next scheduled backup job.
     - Deployment of an automated backup job is a prerequisite for the on-demand job. Only after you initiate an automated backup job, then you can trigger an on-demand backup. 

  2. Check the on-demand backup pods status by running the following command:

     ```
     oc get pods -n velero
     ```

  3. Check the on-demand backup job logs by running the following command:

     ```
     oc logs -f <on-demand-backup-job-***>
     ```

  4. Check the backup status by running the following command:

     ```
     velero get backup <BACKUP_NAME>
     ```

     Where:

      - `<BACKUP_NAME>` is the name of the Backup. You can see the backup name after the on-demand backup job is complete. For example, you might see the backup name `aiops-cluster-backup-106-1622193915` in the on-demand backup job log as follows:
        
        ```
        Waiting for backup aiops-cluster-backup-106-1622193915 to complete

## Troubleshooting

### 1. Velero backup is getting stuck in `In progress` state for long time.

Perform following steps to terminate the backup process :

1. Delete the velero pod.
   
   `oc delete pod <velero pod name> -n <velero installed namespace>`

2. Delete the backup which got stucked in `In progress` state.

   `velero delete backup <backup name>`

3. Wait till backup script execution completion.

### 2. Command `helm install backup-job clusterbackup-0.1.0.tgz` failed with the following error:

```
Error: admission webhook "trust.hooks.securityenforcement.admission.cloud.ibm.com" denied the request:
Deny "<Image Registry Server URL>/<Repository>/cp4waiops-bcdr:latest", no matching repositories in ClusterImagePolicy and no ImagePolicies in the "velero" namespace
```

Where:

   - `<Image Registry Server URL>` is the image registry server URL.
   - `<Repository>` is the repository where you put the image.

As a fix perform the following steps:
   
   1. Uninstall `backup-job` by running the following command:

      ```
      helm uninstall backup-job -n velero
      ```

   2. Create a file `backup-image-policy.yaml` and add the following content to it:
   
      ```
      apiVersion: securityenforcement.admission.cloud.ibm.com/v1beta1
      kind: ClusterImagePolicy
      metadata:
        name: backup-image-policy
      spec:
       repositories:
        - name: "<Image Registry Server URL>/<Repository>/cp4mcm-bcdr:latest"
          policy:
      ```
   
   3. Apply the policy by running the following command:
   
      ```
      oc apply -f backup-image-policy.yaml
      ```

   4. Deploy the backup job by running the following command:

      ```
      helm install backup-job clusterbackup-0.1.0.tgz
