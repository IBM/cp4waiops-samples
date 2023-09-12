#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#
echo "[INFO] $(date) ############## Updating the final backup status for components after Velero backup is completed ##############"

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source $CURRENT/utils.sh
source $WORKDIR/common/common-utils.sh
veleroNamespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.veleroNamespace')
V_TRUE=TRUE
IS_AIOPS_COMPONENT_ENABLED=$(IsComponentEnabled "AIOPS")
IS_IA_COMPONENT_ENABLED=$(IsComponentEnabled "IA")

backupName=$(grep -w name backup.yaml | cut -d " " -f 4)
CASSANDRA_RC=0
COUCHDB_RC=0
MINIO_RC=0

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_TRUE" ]; then
    CASSANDRA_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.CASSANDRA_RC')
    echo "[INFO] $(date) Replica count of statefulset aiops-topology-cassandra is $CASSANDRA_RC"
    COUCHDB_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.COUCHDB_RC')
    echo "[INFO] $(date) Replica count of statefulset c-example-couchdbcluster-m is $COUCHDB_RC"
    MINIO_RC=$(cat $CURRENT/statefulset-rc-data.json | jq '.MINIO_RC')
    echo "[INFO] $(date) Replica count of statefulset aimanager-ibm-minio is $MINIO_RC"
fi


res=$(velero describe backup $backupName --details -n $veleroNamespace |grep  -A10000 -m1 -e 'Restic Backups')
echo "[INFO] $(date) ####### Restic backup status is $res #######"

# Cassandra velero-backup status update:-
index=0
if [[ $res == *"backup-back-aiops-topology-cassandra-0: backup"* ]]; then
    jq '.cassandraBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi
while [ $index -lt $CASSANDRA_RC ]; do
    if [[ $res != *"backup-back-aiops-topology-cassandra-$index: backup"* ]]; then
        jq '.cassandraBackupStatus.velerobackup = false' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
        break
    fi
    index=$((index + 1))
done

# Couchdb velero-backup status update
index=0
if [[ $res == *"backup-data-c-example-couchdbcluster-m-0: backup"* ]]; then
    jq '.couchdbBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi
while [ $index -lt $COUCHDB_RC ]; do
    if [[ $res != *"backup-data-c-example-couchdbcluster-m-$index: backup"* ]]; then
        jq '.couchdbBackupStatus.velerobackup = false' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
        break
    fi
    index=$((index + 1))
done


# Minio velero-backup status update
index=0
if [[ $res == *"backup-export-aimanager-ibm-minio-0: backup"* ]]; then
    jq '.minioBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi
while [ $index -lt $MINIO_RC ]; do
    if [[ $res != *"backup-export-aimanager-ibm-minio-$index: backup"* ]]; then
        jq '.cassandraBackupStatus.velerobackup = false' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
        break
    fi
    index=$((index + 1))
done


# common-services velero-backup status update
if [[ $res == *"dummy-db: mongodump"* ]]; then
    jq '.commonservicesBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

# Metastore velero-backup status update
if [[ $res == *"backup-metastore: data"* ]]; then
    jq '.metastoreBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

# EDB-postgres velero-backup status update
if [[ $res == *"backup-postgres: backup"* ]]; then
    jq '.edbPostgresBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

# Elasticsearch velero-backup status update
if [[ $res == *"es-backup: elasticsearch-backups"* ]]; then
    jq '.elasticsearchBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi


# manage-services velero-backup status update
if [[ $res == *"backup-cam: data"* ]]; then
    jq '.manageservicesBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

# IM velero-backup status update
if [[ $res == *"miq-pgdb-volume"* ]]; then
    jq '.imBackupStatus.velerobackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi
