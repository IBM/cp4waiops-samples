#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================

source ../common/common-utils.sh
CURRENT=$(pwd)
log_file="$CURRENT/install-velero.log"

echo "=============================================" | tee -a "$log_file"

# Reading data from config file
accessKeyId=$(cat install-velero-config.json | jq -r '.aws_access_key_id')
secretAccessKey=$(cat install-velero-config.json | jq -r '.aws_secret_access_key')
namespace=$(cat install-velero-config.json | jq -r '.namespace')
bucketRegion=$(cat install-velero-config.json | jq -r '.bucket_region')
bucketName=$(cat install-velero-config.json | jq -r '.bucket_name')
backupLabel=$(cat install-velero-config.json | jq -r '.backup_label')

installVelero() {

 echo "Inside velero installation function" | tee -a "$log_file"

 # Preparing the bucket credential file
 echo "Preparing the bucket credential file" | tee -a "$log_file"
 rm -f credentials-velero
 echo "[default]" >>credentials-velero
 echo "aws_access_key_id="$accessKeyId >>credentials-velero
 echo "aws_secret_access_key="$secretAccessKey >>credentials-velero

 echo "Creating project for velero installation" | tee -a "$log_file"
 oc new-project $namespace

 echo "Creating secret for velero" | tee -a "$log_file"
 oc create secret generic cloud-credentials -n velero --from-file cloud=credentials-velero

echo "Creating operator group" | tee -a "$log_file"
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: velero-operator-group
  namespace: $namespace
spec:
  targetNamespaces:
  - $namespace
EOF

echo "Waiting for sometime after creating operator group" | tee -a "$log_file"
wait "10"

echo "Creating subscription for oadp operator" | tee -a "$log_file"
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: redhat-oadp-operator
  namespace: $namespace
  annotations:
    argocd.argoproj.io/sync-wave: "10"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  channel: stable
  installPlanApproval: Automatic
  name: redhat-oadp-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for sometime after creating oadp operator subscription" | tee -a "$log_file"
wait "60"
checkPodReadyness $namespace "control-plane=controller-manager" "60"

echo "Creating DataProtectionApplication" | tee -a "$log_file"
cat << EOF | oc apply -f -
apiVersion: oadp.openshift.io/v1alpha1
kind: DataProtectionApplication
metadata:
  name: bcdr-data-protection-app
  namespace: $namespace
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
    argocd.argoproj.io/sync-wave: '20'
spec:
  backupLocations:
    - velero:
        config:
          profile: default
          region: $bucketRegion
        credential:
          key: cloud
          name: cloud-credentials
        default: true
        objectStorage:
          bucket: $bucketName
          prefix: $backupLabel
        provider: aws
  configuration:
    restic:
      enable: true
    velero:
      defaultPlugins:
        - openshift
        - aws
      podConfig:
        resourceAllocations:
          limits:
            cpu: '1'
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi 
EOF

echo "Waiting for sometime after creating DataProtectionApplication" | tee -a "$log_file"
wait "30"
checkPodReadyness $namespace "component=oadp-bcdr-data-protection-app-1-aws-registry" "60"

echo "Creating BackupStorageLocation" | tee -a "$log_file"
cat << EOF | oc apply -f -
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: bcdr-s3-location
  namespace: $namespace
  annotations:
    argocd.argoproj.io/sync-wave: "30"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  config:
    profile: default
    region: $bucketRegion
  credential:
    key: cloud
    name: cloud-credentials
  default: true
  objectStorage:
    bucket: $bucketName
    prefix: $backupLabel
  provider: aws
EOF

echo "Deleting the created credential file" | tee -a "$log_file"
rm -f credentials-velero

echo "Waiting for sometime after creating BackupStorageLocation" | tee -a "$log_file"
wait "30"
checkPodReadyness $namespace "app.kubernetes.io/name=velero" "60"

}

# This function will validate the BackupStorageLocation phase
checkBackupStorageLocation(){
   resourceType=$1
   resourceName=$2
   namespace=$3
   retryCount=$4
   counter=0
   status=$(oc get $resourceType $resourceName -n $namespace -o jsonpath='{.status.phase}')

   # When phase value will be blank then it's value will set to Unavailable to avoid the script failure ([: !=: unary operator expected)
   if [[ $status == "" ]]; then
         echo "BackupStorageLocation phase value is blank hence setting it's value as Unavailable " | tee -a "$log_file"
         status="Unavailable"
         echo $status | tee -a "$log_file"
   fi

   while [ $status != "Available" ]; do
      echo "Waiting for BackupStorageLocation to be Available" | tee -a "$log_file"
      wait "5"
      status=$(oc get $resourceType $resourceName -n $namespace -o jsonpath='{.status.phase}')
      # When phase value will be blank then it's value will set to Unavailable to avoid the script failure ([: !=: unary operator expected)
      if [[ $status == "" ]]; then
           echo "BackupStorageLocation phase value is blank hence setting it's value as Unavailable" | tee -a "$log_file"
           status="Unavailable"
           echo $status | tee -a "$log_file"
      fi
      ((counter++))
      if [[ $counter -eq $retryCount ]]; then
         echo "BackupStorageLocation phase is not Available hence terminating the velero installation process" | tee -a "$log_file"
         exit 1
      fi
   done
}


# Calling required functions
installVelero
checkBackupStorageLocation "BackupStorageLocation" "bcdr-s3-location" $namespace "60"
echo "Velero installation is completed" | tee -a "$log_file"
