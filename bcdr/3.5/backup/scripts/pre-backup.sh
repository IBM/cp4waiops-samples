#!/bin/bash
echo "[INFO] $(date) ############## Pre backup process started ##############"

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/common-utils.sh
source $WORKDIR/backup/scripts/sts-backup.sh
source utils.sh

V_FALSE=FALSE
IS_AIOPS_COMPONENT_ENABLED=$(IsComponentEnabled "AIOPS")
IS_IA_COMPONENT_ENABLED=$(IsComponentEnabled "IA")

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
cs_namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')
mongodb_sc=$(oc get pvc mongodbdir-icp-mongodb-0 -n $cs_namespace -o jsonpath='{.spec.storageClassName}')  
metastore_sc=$(oc get pvc datadir-zen-metastoredb-0 -n $namespace -o jsonpath='{.spec.storageClassName}')  
postgres_sc=$(oc get pvc data-cp4waiops-postgres-keeper-0 -n $namespace -o jsonpath='{.spec.storageClassName}')
rwx_sc=$(oc get pvc iaf-system-elasticsearch-es-snap-es-backup-pvc -n $namespace -o jsonpath='{.spec.storageClassName}')

echo "[INFO] $(date) aiops_namespace: $namespace, cs_namespace: $cs_namespace, mongodb_sc: $mongodb_sc, metastore_sc: $metastore_sc, postgres_sc: $postgres_sc, rwx_sc: $rwx_sc"

sed -i "s/STORAGE_CLASS/$mongodb_sc/g" $CURRENT/common-services/mongodb-dump.yaml
sed -i "s/STORAGE_CLASS/$metastore_sc/g" $CURRENT/metastore/metastore-backup.yaml
sed -i "s/STORAGE_CLASS/$postgres_sc/g" $CURRENT/postgres/postgres-backup.yaml
sed -i "s/STORAGE_CLASS/$rwx_sc/g" $CURRENT/other-resources/other-resources-backup.yaml

cp resource-label-details.json /workdir/resource-label-details.json
cp pod-annotation-details.json /workdir/pod-annotation-details.json
cp backup_original.yaml /workdir/backup_original.yaml
cp enabled-namespaces.json /workdir/enabled-namespaces.json

sed -i "s/AIOPS_NAMESPACE/$namespace/g" /workdir/resource-label-details.json
sed -i "s/AIOPS_NAMESPACE/$namespace/g" /workdir/pod-annotation-details.json
sed -i "s/AIOPS_NAMESPACE/$namespace/g" /workdir/backup_original.yaml
sed -i "s/AIOPS_NAMESPACE/$namespace/g" /workdir/enabled-namespaces.json

sed -i "s/CS_NAMESPACE/$cs_namespace/g" /workdir/resource-label-details.json
sed -i "s/CS_NAMESPACE/$cs_namespace/g" /workdir/pod-annotation-details.json
sed -i "s/CS_NAMESPACE/$cs_namespace/g" /workdir/backup_original.yaml
sed -i "s/CS_NAMESPACE/$cs_namespace/g" /workdir/enabled-namespaces.json

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [AIOPS] is not enabled, hence skipping AIOPS related pre backup steps"
else
   echo "[INFO] $(date) Component [AIOPS] is enabled, hence performing AIOPS related pre backup steps"
   #Getting the replica count before scaling down the required pods
   CASSANDRA_RC=$(oc get sts aiops-topology-cassandra -n $namespace -o=jsonpath='{.spec.replicas}')
   COUCHDB_RC=$(oc get sts c-example-couchdbcluster-m -n $namespace -o=jsonpath='{.spec.replicas}')
   MINIO_RC=$(oc get sts aimanager-ibm-minio -n $namespace -o=jsonpath='{.spec.replicas}')

   echo "[INFO] $(date) Before scaling down aiops-topology-cassandra statefulset replica count is $CASSANDRA_RC"
   echo "[INFO] $(date) Before scaling down c-example-couchdbcluster-m statefulset replica count is $COUCHDB_RC"
   echo "[INFO] $(date) Before scaling down aimanager-ibm-minio statefulset replica count is $MINIO_RC"

   echo "[INFO] $(date) Checking if native Cassandra backup happenned successfully"
   cassandraBackup="success"
   cassandraPodList=$( oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9] )
   for pod in $cassandraPodList; do
       backup_tarfile=$( oc exec $pod -n $namespace -- bash -c "ls /opt/ibm/cassandra/data/backup_tar -rt | tail -1" )
       if [ -z "$backup_tarfile" ]
       then
           echo "[ERROR] $(date) No Cassandra backup tar file is created in pod $pod"
           cassandraBackup="failure"
           break
       else
           echo "[INFO] $(date) Cassandra backup tar $backup_tarfile file is created successfully in $pod!"
       fi
   done
   
   # Updating the backup result for Cassandra
   if [ "$cassandraBackup" == "success" ]; then
       jq '.cassandraBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
   fi

   #Saving the replica count values to a json file as it's required for monitoring-post-backup-task script
   JSON='{"CASSANDRA_RC": '"$CASSANDRA_RC"', "COUCHDB_RC": '"$COUCHDB_RC"', "MINIO_RC": '"$MINIO_RC"'  }'
   rm -f statefulset-rc-data.json
   echo $JSON > statefulset-rc-data.json
   
   #Scaling down the required pods
   oc scale sts aiops-topology-cassandra c-example-couchdbcluster-m aimanager-ibm-minio --replicas=0 -n $namespace
   
   # Creating customized backup pods
   if [ "$cassandraBackup" == "success" ]; then
       CreateBackupPods "aiops-topology-cassandra" "back" $CASSANDRA_RC $namespace "./sts-backup-pod-template.yaml"
   fi
   CreateBackupPods "c-example-couchdbcluster-m" "data" $COUCHDB_RC $namespace "./sts-backup-pod-template.yaml"
   CreateBackupPods "aimanager-ibm-minio" "export" $MINIO_RC $namespace "./sts-backup-pod-template.yaml"
   oc create -f elasticsearch/es-backup-pod.yaml -n $namespace
   oc create -f other-resources/other-resources-backup.yaml -n $namespace
   checkResourceReadyness $namespace "restic-backup-pod=t" "20" "pod"

fi

# Disabling zen-metastore-backup-cron-job
oc patch cronjobs zen-metastore-backup-cron-job -p '{"spec" : {"suspend" : true }}' -n $namespace


if [ "$IS_IA_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [IA] is not enabled, hence skipping IA related pre backup steps"
else
   echo "[INFO] $(date) Component [IA] is enabled, hence performing IA related pre backup steps"
   CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC=$(oc get deploy cam-install-operator-controller-manager -n $namespace -o=jsonpath='{.spec.replicas}')
   CAM_MONGO_RC=$(oc get deploy cam-mongo -n $namespace -o=jsonpath='{.spec.replicas}')
   echo "[INFO] $(date) Before scaling down cam-install-operator-controller-manager deployment replica count is $CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC"
   echo "[INFO] $(date) Before scaling down cam-mongo deployment replica count is $CAM_MONGO_RC"
   
   #Saving the replica count values to a json file as it's required for post-backup script
   JSON='{ "CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC": '"$CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC"', "CAM_MONGO_RC": '"$CAM_MONGO_RC"'  }'
   rm -f cam-rc-data.json
   echo $JSON > cam-rc-data.json
   
   oc scale deployment cam-install-operator-controller-manager cam-mongo --replicas=0 -n $namespace
   
   # Creating customized backup pod for cam
   oc create -f cam/cam-backup.yaml -n $namespace
   checkResourceReadyness $namespace "restic-backup-pod=t" "20" "pod"
fi

echo "[INFO] $(date) ############## Pre backup process completed ##############"
