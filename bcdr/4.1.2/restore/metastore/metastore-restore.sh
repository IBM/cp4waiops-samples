#!/bin/bash
#*===================================================================
#*
#   IBM Confidential
#   5737-M96
#   (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
#   
#   
#*
#*===================================================================

echo "[INFO] $(date) ############## Metastore restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')

metastoreRestoreNamePrefix="metastore-restore"
metastoreRestoreLabel="metastore.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, metastoreRestoreNamePrefix: $metastoreRestoreNamePrefix, metastoreRestoreLabel: $metastoreRestoreLabel"

performMetastoreDbRestore() {

      #Getting the replica count before scaling down the required pods
      IBM_NGINX_RC=$(oc get deploy ibm-nginx -n $namespace -o=jsonpath='{.spec.replicas}')
      echo "[INFO] $(date) Before scaling down ibm-nginx deployement replica count is $IBM_NGINX_RC"
      ZEN_CORE_RC=$(oc get deploy zen-core -n $namespace -o=jsonpath='{.spec.replicas}')
      echo "[INFO] $(date) Before scaling down zen-core deployement replica count is $ZEN_CORE_RC"
      USERMGMT_RC=$(oc get deploy usermgmt -n $namespace -o=jsonpath='{.spec.replicas}')
      echo "[INFO] $(date) Before scaling down usermgmt deployement replica count is $USERMGMT_RC"
      ZEN_CORE_API_RC=$(oc get deploy zen-core-api -n $namespace -o=jsonpath='{.spec.replicas}')
      echo "[INFO] $(date) Before scaling down zen-core-api deployement replica count is $ZEN_CORE_API_RC"
      ZEN_WATCHER_RC=$(oc get deploy zen-watcher -n $namespace -o=jsonpath='{.spec.replicas}')
      echo "[INFO] $(date) Before scaling down zen-watcher deployement replica count is $ZEN_WATCHER_RC"
      
      # Scaling down the required deployements
      oc scale deploy -n $namespace ibm-nginx zen-core usermgmt zen-watcher zen-core-api --replicas=0
      echo "[INFO] $(date) Waiting for some time after scaling down the deployements"
      wait "60"
      
      {  # try
         oc exec -i -t zen-metastoredb-0 -n $namespace -- mkdir /user-home/zen-metastoredb-backup &&
         echo "[INFO] $(date) Directory /user-home/zen-metastoredb-backup gets created successfully!" 
      } || { # catch
         echo "[WARNING] $(date) Directory /user-home/zen-metastoredb-backup creation failed!"
      }
      
      # Performing restore
      {  # try
         oc cp -n $namespace backup-metastore:/usr/share/backup/zen-metastoredb-backup.tar /tmp/zen-metastoredb-backup.tar &&
         oc cp -n $namespace /tmp/zen-metastoredb-backup.tar zen-metastoredb-0:/user-home/zen-metastoredb-backup/zen-metastoredb-backup.tar &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "cd /user-home/zen-metastoredb-backup && tar xvf zen-metastoredb-backup.tar" &&
         echo "[INFO] $(date) Backup file from backup-metastore to metastore pod transferred!" 
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "rm -rf /user-home/_global_/config/jwt_old"
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "mv /user-home/_global_/config/jwt /user-home/_global_/config/jwt_old" &&
         oc cp -n $namespace backup-metastore:/usr/share/backup/jwt.tar /tmp/jwt.tar &&
         oc cp -n $namespace /tmp/jwt.tar zen-metastoredb-0:/user-home/_global_/config/jwt.tar &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "cd /user-home/_global_/config && tar xvf jwt.tar" &&
         oc exec zen-metastoredb-0 -n $namespace -- bash -c "rm -rf /user-home/_global_/config/jwt.tar" &&
         echo "[INFO] $(date) user-home updated with jwt from backup cluster!"

      } || { # catch
         echo "[ERROR] $(date) Transfer of backup file to backup-metastore pod failed, hence exiting!" &&
	 $WORKDIR/restore/metastore/metastore-post-restore.sh &&
	 performMetastoreNativePostRestore &&
	 exit 1
      }

      csOperatorCsvName=$(oc get csv -n $namespace | grep ibm-common-service-operator |  cut -d " " -f 1)
      echo "[DEBUG] $(date) Common service operator csv name is $csOperatorCsvName"
      csOperatorVersion=$(oc get csv -n $namespace $csOperatorCsvName -o jsonpath='{.spec.version}')
      echo "[DEBUG] $(date) Common service operator version is $csOperatorVersion"
      zenVersion=$(oc get deploy zen-watcher -n $namespace -o jsonpath='{.spec.template.metadata.annotations.productVersion}')
      echo "[DEBUG] $(date) Zen version is $zenVersion"
            
      if [[ (($csOperatorVersion < 3.22.0)) && (($zenVersion < 4.8.0)) ]]; then
            echo "[INFO] $(date) CS operator version is less than 3.22.0 and Zen version is less than 4.8.0"
            echo "[INFO] $(date) Reseting DB before restore"
            oc exec zen-metastoredb-0 -n $namespace -- bash -c "cp -r /certs/..data/ /tmp/certs"
            oc exec zen-metastoredb-0 -n $namespace -- bash -c "cd /tmp && chmod 0600 ./certs/*"
            oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="drop database if exists zen cascade; drop database if exists spark cascade;"
            oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="create database if not exists zen; create user if not exists zen_user; grant all on database zen to zen_user;"
            oc exec -i -t zen-metastoredb-0 -n $namespace -- /cockroach/cockroach sql --certs-dir=/tmp/certs/ --host=zen-metastoredb-0.zen-metastoredb --execute="create database if not exists spark; create user if not exists spark_user; grant all on database spark to spark_user;"
            
            echo "[INFO] $(date) Executing metastore native restore script"
            oc exec -i -t zen-metastoredb-0 -n $namespace -- /tmp/backup/restore_script.sh
      else
            echo "[INFO] $(date) CS operator version is greater than or equal to 3.22.0"
            echo "[INFO] $(date) Executing metastore native restore script"
            oc exec -i -t zen-metastoredb-0 -n $namespace -- /tmp/backup/restore_script.sh regular zen-operator
      fi
      
      # Scaling up the deployments
      performMetastoreNativePostRestore 
      echo "[INFO] $(date) Waiting for some time after scaling up the deployements"
      wait "30"
      
}

performMetastoreNativePostRestore() {
      # Scaling up the deployments
      echo "Scaling up the deployments"
      oc scale deploy -n $namespace ibm-nginx --replicas=$IBM_NGINX_RC
      oc scale deploy -n $namespace zen-core --replicas=$ZEN_CORE_RC
      oc scale deploy -n $namespace usermgmt --replicas=$USERMGMT_RC
      oc scale deploy -n $namespace zen-core-api --replicas=$ZEN_CORE_API_RC
      oc scale deploy -n $namespace zen-watcher --replicas=$ZEN_WATCHER_RC
}

echo "[INFO] $(date) Disabling zen-metastore-backup-cron-job"
oc patch cronjobs zen-metastore-backup-cron-job -p '{"spec" : {"suspend" : true }}' -n $namespace

echo "[WARNING] $(date) Deleting existing secret zen-secrets-aes-key to be replaced with one from velero backup"
oc get secret -n $namespace zen-secrets-aes-key -o yaml > $WORKDIR/restore/metastore/zen-secrets-aes-key-pre-restore.yaml
oc delete secret zen-secrets-aes-key -n $namespace

echo "[INFO] $(date) Performing velero restore for metastore"
performVeleroRestore $metastoreRestoreNamePrefix $backupName $namespace $metastoreRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/metastore/metastore-post-restore.sh
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "metastore-backup-data"
pvcCheckReturnValue=$?
if [ $pvcCheckReturnValue -ne 0 ]; then
    echo "[ERROR] $(date) PVC check has failed with return value $pvcCheckReturnValue"
    $WORKDIR/restore/metastore/metastore-post-restore.sh
    exit 1
fi

echo "[INFO] $(date) Executing metastore db restore"
performMetastoreDbRestore

echo "[WARNING] $(date) Deleting restored pod and pvc"
oc delete po -n $namespace -l metastore.cp4aiops.ibm.com/backup=t
oc delete pvc -n $namespace -l metastore.cp4aiops.ibm.com/backup=t

# Wait till ibm-nginx zen-core usermgmt zen-core-api zen-watcher pods are ready
checkPodReadyness $namespace "app.kubernetes.io/component=ibm-nginx" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-core" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=usermgmt" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-core-api" "60"
checkPodReadyness $namespace "app.kubernetes.io/component=zen-watcher" "60"

echo "[INFO] $(date) Restoring SERVICE_INSTANCE_ID"
oc get deploy -n $namespace aimanager-aio-controller -o yaml > $WORKDIR/restore/metastore/aimanager-aio-controller-deploy-before-change.yaml
service_instance_id=$(oc get cm metastore-bcdr-config -n $namespace -o jsonpath='{.data.serviceInstanceId}')
echo "[INFO] $(date) SERVICE_INSTANCE_ID value is $service_instance_id"
oc set env deployment aimanager-aio-controller SERVICE_INSTANCE_ID=$service_instance_id -n $namespace 

echo "[INFO] $(date) Waiting for some time after updating SERVICE_INSTANCE_ID in deployment aimanager-aio-controller"
wait "30"
oc delete po -n $namespace -l app.kubernetes.io/component=controller
checkPodReadyness $namespace "app.kubernetes.io/component=controller" "60"

$WORKDIR/restore/metastore/metastore-post-restore.sh

echo "[INFO] $(date) ############## Metastore restore completed ##############"
