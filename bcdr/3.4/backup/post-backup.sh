#!/bin/bash

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source $CURRENT/utils.sh
source ../common/common-utils.sh

backupName=$(grep -w name backup.yaml | cut -d " " -f 4)
echo $backupName
waitTillBackupCompletion "$backupName"

namespace=$(cat ../common/aiops-config.json | jq -r '.aiopsNamespace')
cs_namespace=$(cat ../common/aiops-config.json | jq -r '.csNamespace')

# Deleteing all the customized backup pods
oc delete po -l restic-backup-pod=t -n $namespace

CASSANDRA_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.CASSANDRA_RC')
echo Scaling up replica count of statefulset aiops-topology-cassandra to $CASSANDRA_RC
COUCHDB_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.COUCHDB_RC')
echo Scaling up replica count of statefulset c-example-couchdbcluster-m to $COUCHDB_RC
MINIO_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.MINIO_RC')
echo Scaling up replica count of statefulset aimanager-ibm-minio to $MINIO_RC

oc scale sts aiops-topology-cassandra --replicas=$CASSANDRA_RC -n $namespace
oc scale sts c-example-couchdbcluster-m --replicas=$COUCHDB_RC -n $namespace
oc scale sts aimanager-ibm-minio --replicas=$MINIO_RC -n $namespace

# Delete metastore backup pvc
oc delete pvc metastore-backup-data -n $namespace

# Delete postgresql backup pvc
oc delete pvc postgres-backup-data -n $namespace

# Delete other resource backup pvc
oc delete pvc other-resources-backup-data -n $namespace

# Deleting common services backup job and pvc
oc delete job icp-mongodb-backup -n $cs_namespace
oc delete po dummy-db -n $cs_namespace
oc delete pvc my-mongodump -n $cs_namespace

# Wait till cassandra, couchdb and minio pods are ready
checkPodReadyness $namespace "app=cassandra" "60"
checkPodReadyness $namespace "app.kubernetes.io/name=ibm-minio" "60"
#checkPodReadyness $namespace "app.kubernetes.io/instance=example-couchdbcluster" "60"

