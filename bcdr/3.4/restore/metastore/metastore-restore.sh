#!/bin/bash
#*===================================================================
#*
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#*
#*===================================================================

source ../restore-utils.sh
source ../../common/common-utils.sh
source ../../common/prereq-check.sh

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat ../restore-data.json | jq -r '.backupName')

metastoreRestoreNamePrefix="metastore-restore"
metastoreRestoreLabel="metastore.cp4aiops.ibm.com/backup=t"
echo $namespace $backupName $metastoreRestoreNamePrefix $metastoreRestoreLabel

performMetastoreDbRestore() {

      #Getting the replica count before scaling down the required pods
      IBM_NGINX_RC=$(oc get deploy ibm-nginx -n $namespace -o=jsonpath='{.spec.replicas}')
      echo Before scaling down ibm-nginx deployement replica count is $IBM_NGINX_RC
      ZEN_CORE_RC=$(oc get deploy zen-core -n $namespace -o=jsonpath='{.spec.replicas}')
      echo Before scaling down zen-core deployement replica count is $ZEN_CORE_RC
      USERMGMT_RC=$(oc get deploy usermgmt -n $namespace -o=jsonpath='{.spec.replicas}')
      echo Before scaling down usermgmt deployement replica count is $USERMGMT_RC
      ZEN_CORE_API_RC=$(oc get deploy zen-core-api -n $namespace -o=jsonpath='{.spec.replicas}')
      echo Before scaling down zen-core-api deployement replica count is $ZEN_CORE_API_RC
      ZEN_WATCHER_RC=$(oc get deploy zen-watcher -n $namespace -o=jsonpath='{.spec.replicas}')
      echo Before scaling down zen-watcher deployement replica count is $ZEN_WATCHER_RC
      
      # Scaling down the required deployements
      oc scale deploy -n $namespace ibm-nginx zen-core usermgmt zen-watcher zen-core-api --replicas=0
      echo "Waiting for some time after scaling down the deployements"
      wait "60"
      
      {  # try
         oc exec -i -t zen-metastoredb-0 -n $namespace -- mkdir /user-home/zen-metastoredb-backup &&
         echo "Directory /user-home/zen-metastoredb-backup gets created successfully!" 
      } || { # catch
         echo "Directory /user-home/zen-metastoredb-backup creation failed!"
      }
      
      # Performing restore
      {  # try
         oc cp -n $namespace backup-metastore:/usr/share/backup/zen-metastoredb-backup.tar /tmp/zen-metastoredb-backup.tar &&
         oc cp -n $namespace /tmp/zen-metastoredb-backup.tar zen-metastoredb-0:/user-home/zen-metastoredb-backup/zen-metastoredb-backup.tar &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "cd /user-home/zen-metastoredb-backup && tar xvf zen-metastoredb-backup.tar" &&
         echo "Backup file from backup-metastore to metastore pod transferred!" 

         oc exec zen-metastoredb-0 -n $namespace -- bash -c "mv /user-home/_global_/config/jwt /user-home/_global_/config/jwt_old" &&
         oc cp -n $namespace backup-metastore:/usr/share/backup/jwt.tar /tmp/jwt.tar &&
         oc cp -n $namespace /tmp/jwt.tar zen-metastoredb-0:/user-home/_global_/config/jwt.tar &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "cd /user-home/_global_/config && tar xvf jwt.tar" &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "rm -rf /user-home/_global_/config/jwt.tar" &&
         echo "user-home updated with jwt from backup cluster!" 

      } || { # catch
         echo "Transfer of backup file to backup-metastore pod failed, hence exiting!" && exit 1
      }

      # Reseting DB before restore
      oc exec -i -t zen-metastoredb-0 -n $namespace -- cp -r /certs/ /tmp/
      oc exec -i -t zen-metastoredb-0 -n $namespace -- chmod -R  0700 /tmp/certs/
      oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="drop database if exists zen cascade; drop database if exists spark cascade;"
      oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="create database if not exists zen; create user if not exists zen_user; grant all on database zen to zen_user;"
      oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="create database if not exists spark; create user if not exists spark_user; grant all on database spark to spark_user;"

      # Restore
      oc exec -i -t zen-metastoredb-0 -n $namespace -- /tmp/backup/restore_script.sh
      
      # Scaling up the deployments
      oc scale deploy -n $namespace ibm-nginx --replicas=$IBM_NGINX_RC
      oc scale deploy -n $namespace zen-core --replicas=$ZEN_CORE_RC
      oc scale deploy -n $namespace usermgmt --replicas=$USERMGMT_RC
      oc scale deploy -n $namespace zen-core-api --replicas=$ZEN_CORE_API_RC
      oc scale deploy -n $namespace zen-watcher --replicas=$ZEN_WATCHER_RC
      
      echo "Waiting for some time after scaling up the deployements"
      wait "30"
      
}

# delete existing secret zen-secrets-aes-key to be replaced with one from velero backup
oc delete secret zen-secrets-aes-key -n $namespace

# Performing velero restore for metastore
performVeleroRestore $metastoreRestoreNamePrefix $backupName $namespace $metastoreRestoreLabel

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "metastore-backup-data"

# Execute metastore db restore
performMetastoreDbRestore

# Delete restored pod and pvc 
oc delete po -n $namespace -l metastore.cp4aiops.ibm.com/backup=t
oc delete pvc -n $namespace -l metastore.cp4aiops.ibm.com/backup=t

# Wait till ibm-nginx zen-core usermgmt zen-core-api zen-watcher pods are ready
checkPodReadyness $namespace "app.kubernetes.io/component=ibm-nginx" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-core" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=usermgmt" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-core-api" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-watcher" "60"

# Restoring SERVICE_INSTANCE_ID
oc get deploy -n $namespace aimanager-aio-controller -o yaml > aimanager-aio-controller-deploy-before-change.yaml
service_instance_id=$(oc get cm metastore-bcdr-config -n $namespace -o jsonpath='{.data.serviceInstanceId}')
echo "SERVICE_INSTANCE_ID value is $service_instance_id"
oc set env deployment aimanager-aio-controller SERVICE_INSTANCE_ID=$service_instance_id -n $namespace 

echo "Waiting for some time after updating SERVICE_INSTANCE_ID in deployment aimanager-aio-controller"
wait "30"
checkPodReadyness $namespace "app.kubernetes.io/component=controller" "60"


oc delete configmap metastore-bcdr-config -n $namespace 

echo "Zen MetastoreDB restore is completed"
