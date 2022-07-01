#!/bin/bash

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source ../common/common-utils.sh
source ./sts-backup.sh

namespace=$(cat ../common/aiops-config.json | jq -r '.aiopsNamespace')
cs_namespace=$(cat ../common/aiops-config.json | jq -r '.csNamespace')
mongodb_sc=$(oc get pvc mongodbdir-icp-mongodb-0 -n $cs_namespace -o jsonpath='{.spec.storageClassName}')  
metastore_sc=$(oc get pvc datadir-zen-metastoredb-0 -n $namespace -o jsonpath='{.spec.storageClassName}')  
postgres_sc=$(oc get pvc data-cp4waiops-postgres-keeper-0 -n $namespace -o jsonpath='{.spec.storageClassName}')
rwx_sc=$(oc get pvc iaf-system-elasticsearch-es-snap-es-backup-pvc -n $namespace -o jsonpath='{.spec.storageClassName}')

echo $namespace $cs_namespace $mongodb_sc $metastore_sc $postgres_sc $rwx_sc

sed -i "s/STORAGE_CLASS/$mongodb_sc/g" $CURRENT/common-services/mongodb-dump.yaml
sed -i "s/STORAGE_CLASS/$metastore_sc/g" $CURRENT/metastore/metastore-backup.yaml
sed -i "s/STORAGE_CLASS/$postgres_sc/g" $CURRENT/postgres/postgres-backup.yaml
sed -i "s/STORAGE_CLASS/$rwx_sc/g" $CURRENT/other-resources/other-resources-backup.yaml

sed -i "s/AIOPS_NAMESPACE/$namespace/g" resource-label-details.json
sed -i "s/AIOPS_NAMESPACE/$namespace/g" pod-annotation-details.json
sed -i "s/AIOPS_NAMESPACE/$namespace/g" backup_original.yaml
sed -i "s/AIOPS_NAMESPACE/$namespace/g" enabled-namespaces.json

sed -i "s/CS_NAMESPACE/$cs_namespace/g" resource-label-details.json
sed -i "s/CS_NAMESPACE/$cs_namespace/g" pod-annotation-details.json
sed -i "s/CS_NAMESPACE/$cs_namespace/g" backup_original.yaml
sed -i "s/CS_NAMESPACE/$cs_namespace/g" enabled-namespaces.json

#Getting the replica count before scaling down the required pods
CASSANDRA_RC=$(oc get sts aiops-topology-cassandra -n $namespace -o=jsonpath='{.spec.replicas}')
COUCHDB_RC=$(oc get sts c-example-couchdbcluster-m -n $namespace -o=jsonpath='{.spec.replicas}')
MINIO_RC=$(oc get sts aimanager-ibm-minio -n $namespace -o=jsonpath='{.spec.replicas}')

echo Before scaling down aiops-topology-cassandra statefulset replica count is $CASSANDRA_RC
echo Before scaling down c-example-couchdbcluster-m statefulset replica count is $COUCHDB_RC
echo Before scaling down aimanager-ibm-minio statefulset replica count is $MINIO_RC

echo "Checking if native Cassandra backup happenned successfully"
cassandraBackup="success"
cassandraPodList=$( oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9] )
for pod in $cassandraPodList; do
    backup_tarfile=$( oc exec $pod -n $namespace -- bash -c "ls /opt/ibm/cassandra/data/backup_tar -rt | tail -1" )
    if [ -z "$backup_tarfile" ]
    then
        echo "No Cassandra backup tar file is created in pod $pod"
        cassandraBackup="failure"
        break
    else
        echo "Cassandra backup tar $backup_tarfile file is created successfully in $pod!"
    fi
done

#Saving the replica count values to a json file as it's required for monitoring-post-backup-task script
JSON='{"CASSANDRA_RC": '"$CASSANDRA_RC"', "COUCHDB_RC": '"$COUCHDB_RC"', "MINIO_RC": '"$MINIO_RC"' }'
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

