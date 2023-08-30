#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#
echo "[INFO] $(date) ############## Post backup process started ##############"

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source $CURRENT/utils.sh
source $WORKDIR/common/common-utils.sh

V_FALSE=FALSE
IS_AIOPS_COMPONENT_ENABLED=$(IsComponentEnabled "AIOPS")
IS_IA_COMPONENT_ENABLED=$(IsComponentEnabled "IA")

backupName=$(grep -w name backup.yaml | cut -d " " -f 4)
echo "[INFO] $(date) Backup name is $backupName"
waitTillBackupCompletion "$backupName"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
cs_namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')

echo "[WARNING] $(date) Deleteing all the customized backup pods"
oc delete po -l restic-backup-pod=t -n $namespace

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [AIOPS] is not enabled, hence skipping AIOPS related post backup steps"
else
   echo "[INFO] $(date) Component [AIOPS] is enabled, hence performing AIOPS related post backup steps"
   CASSANDRA_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.CASSANDRA_RC')
   echo "[INFO] $(date) Scaling up replica count of statefulset aiops-topology-cassandra to $CASSANDRA_RC"
   COUCHDB_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.COUCHDB_RC')
   echo "[INFO] $(date) Scaling up replica count of statefulset c-example-couchdbcluster-m to $COUCHDB_RC"
   MINIO_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.MINIO_RC')
   echo "[INFO] $(date) Scaling up replica count of statefulset aimanager-ibm-minio to $MINIO_RC"
   REDIS_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.REDIS_RC')
   echo "[INFO] $(date) Scaling up replica count of statefulset c-example-redis-m to $REDIS_RC"
   IRCORE_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.IRCORE_RC')
   echo "[INFO] $(date) Scaling up replica count of deployment ir-core-operator-controller-manager to $IRCORE_RC"
   oc scale deploy -n $namespace ir-core-operator-controller-manager --replicas=$IRCORE_RC
   oc scale sts aiops-topology-cassandra --replicas=$CASSANDRA_RC -n $namespace
   oc scale sts c-example-couchdbcluster-m --replicas=$COUCHDB_RC -n $namespace
   oc scale sts aimanager-ibm-minio --replicas=$MINIO_RC -n $namespace
   oc scale sts c-example-redis-m  --replicas=$REDIS_RC -n $namespace
   
   echo "[WARNING] $(date) Deleteing IBM postgresql backup pvc"
   oc delete pvc postgres-backup-data -n $namespace
   
   echo "[WARNING] $(date) Deleteing other resource backup pvc"
   oc delete pvc other-resources-backup-data -n $namespace
fi

echo "[WARNING] $(date) Deleteing common services backup job and pvc"
oc delete job icp-mongodb-backup -n $cs_namespace
oc delete po dummy-db -n $cs_namespace
oc delete pvc my-mongodump -n $cs_namespace

echo "[WARNING] $(date) Deleteing metastore backup pvc"
oc delete pvc metastore-backup-data -n $namespace
echo "[INFO] $(date) Enabling zen-metastore-backup-cron-job"
oc patch cronjobs zen-metastore-backup-cron-job -p '{"spec" : {"suspend" : false }}' -n $namespace

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [AIOPS] is not enabled, hence skipping AIOPS related post backup steps"
else
   echo "[INFO] $(date) Component [AIOPS] is enabled, hence performing AIOPS related post backup steps"
   echo "[INFO] $(date) Wait till cassandra, couchdb and minio pods are ready"
   checkPodReadyness $namespace "app=cassandra" "60"
   checkPodReadyness $namespace "app.kubernetes.io/name=ibm-minio" "60"
   #checkPodReadyness $namespace "app.kubernetes.io/instance=example-couchdbcluster" "60"
fi

if [ "$IS_IA_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [IA] is not enabled, hence skipping IA related post backup steps"
else
   echo "[INFO] $(date) Component [IA] is enabled, hence performing IA related post backup steps"
   CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC=$(cat $CURRENT/cam-rc-data.json | jq '.CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC')
   echo "[INFO] $(date) Scaling up replica count of deployment cam-install-operator-controller-manager to $CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC"
   CAM_MONGO_RC=$(cat $CURRENT/cam-rc-data.json | jq '.CAM_MONGO_RC')
   echo "[INFO] $(date) Scaling up replica count of deployment cam-mongo to $CAM_MONGO_RC"
   
   oc scale deployment cam-install-operator-controller-manager --replicas=$CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC -n $namespace
   oc scale deployment cam-mongo --replicas=$CAM_MONGO_RC -n $namespace
fi

echo "[INFO] $(date) ############## Post backup process completed ##############"

