© Copyright IBM Corp. 2021, 2024

# Prepare the CP4AIOps Cluster for Backup 

There are several steps to follow so that your cluster is ready for backup:
- [Provision S3 bucket](#provision-s3-bucket)
- [Install command line tools on your workstation](#install-command-line-tools)
- [Install Velero on the cluster](#install-velero)
- [Update ElasticSearch storage and permissions](#update-elasticsearch-storage-and-permissions)

## Provision S3 bucket
The backup process will move the backup files to an S3 bucket.   This can be in AWS, IBM Cloud, or other s3 compatible locations.  Only AWS has been tested.

## Install command line tools
- Install `kubectl`, `oc`, and `jq` CLIs on a workstation machine where you want to run the `install-oadp` script.
- Install velero client CLI
   - The Velero client CLI will be needed on the workstation where you plan to execute scripts for backing up and restoring the cluster
     
 - Steps to install Velero Client on Ubuntu:
     - `wget https://github.com/vmware-tanzu/velero/releases/download/v1.9.1/velero-v1.9.1-linux-amd64.tar.gz`
   - Extract the tarball:
     - `tar -xvf velero-v1.9.1-linux-amd64.tar.gz -C /tmp`
   - Move the extracted velero binary to /usr/local/bin
     - `sudo mv /tmp/velero-v1.9.1-linux-amd64/velero /usr/local/bin`
   - Verify the installation:
      ```
      velero version
      Client:
          Version: v1.9.1
          Git commit: e4c84b7b3d603ba646364d5571c69a6443719bf2
      ```


## Install OADP
You need to install Velero and Restic using the Red Hat OADP Operator

1. Clone this repository

2.   ```
     cd <path of cloned repo>/install
     ```

3. Update the following parameters in `install-oadp-config.json`:

     - aws_access_key_id: Access key id to connect to S3 bucket.
     - aws_secret_access_key: Secret access key to connect to S3 bucket.
     - bucket_name: Name of the S3 bucket where backup data will be stored.
     - bucket_region: Region where S3 bucket is deployed.
     - namespace: Namespace name in which you want to deploy OADP, if namespace will be not there in cluster then it will be created
     - backup_label: This label is used to create folder structure to organize sets of backups together
4. Log in to the OpenShift cluster

5. Install Velero using the following command:

     ```
     nohup ./install-oadp.sh > install-oadp.log &
     ```

     Check the logs by running the following command:

     ```
     tail -f install-oadp.log
     ```

## Troubleshooting

### 1. Backups are not showing after installation.

Perform following steps to show the backups :

1. Correct the `bucket` and `prefix` property in `bcdr-s3-location` backupstoragelocation and that can be done using kubectl edit command. Here `bucket` and `prefix` name should be same as mentioned in `install-velero-config.json` file during OADP installation in source cluster.

   `kubectl edit backupstoragelocation bcdr-s3-location -n <OADP installed namespace>`

2. Delete the velero pod.

   `kubectl delete po <velero pod name> -n <OADP installed namespace>`

3. Now backups should be showing

   `velero get backup`
   
### 2. OADP installation is failing

If OADP installation is failing after running script `install-oadp.sh` due to below error then rerun the script again. This may be due to the network or cluster itself being slow where pod's may not come in a running state, in such case please re-run `install-oadp.sh` script again.

```
error: unable to recognize "STDIN": no matches for kind "DataProtectionApplication" in version "oadp.openshift.io/v1alpha1"
```
