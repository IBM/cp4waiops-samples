#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

# We assume you have oc installed in the environment. And you already logged into the cluster as the admin.
# This scripts accepts two parameters: secret, pod.
# If the arguments are not supplied, the script will use default values.

#set -x
echo "[INFO] $(date) ############## EDB Postgres restore started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT
source $WORKDIR/common/common-utils.sh
source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/prereq-check.sh

install=$(oc get installations.orchestrator.aiops.ibm.com --all-namespaces | grep -v '^NAMESPACE')
ns=$(echo $install | awk '{print $1}')
installation=$(echo $install | awk '{print $2}')
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
edbPostgresRestoreNamePrefix="edb-postgres-restore"
edbPostgresRestoreLabel="postgres.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $ns, backupName: $backupName, edbPostgresRestoreNamePrefix: $edbPostgresRestoreNamePrefix, edbPostgresRestoreLabel: $edbPostgresRestoreLabel"

echo "[INFO] $(date) Performing velero restore for IBM postgres"
performVeleroRestore $edbPostgresRestoreNamePrefix $backupName $ns $edbPostgresRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post retore steps for cleanup now before exit"
      $WORKDIR/restore/postgres/postgres-post-restore.sh
      exit 1
fi

# Check if required pvc is created through velero restore or not
checkPvcStatus $ns "postgres-backup-data"
pvcCheckReturnValue=$?
if [ $pvcCheckReturnValue -ne 0 ]; then
    echo "[ERROR] $(date) PVC check has failed with return value $pvcCheckReturnValue"
    $WORKDIR/restore/postgres/postgres-post-restore.sh
    exit 1
fi


secrets=$(cat $WORKDIR/common/postgres-db-secrets.json | jq -r '.[]')
for secret in $secrets; do
  echo "[INFO] $(date) Collecting information"
  #secret=aimanager-edb-postgresdb-secret
  #[ -n "$1" ] && secret=$1
  uuid=$(cat /proc/sys/kernel/random/uuid)
  oc -n $ns get secret $installation-edb-secret -o yaml > /tmp/secret1.$uuid || { echo "[ERROR] $(date) Cannot find secret $installation-edb-secret in namespace $ns, hence exiting!"; $WORKDIR/restore/postgres/postgres-post-restore.sh; exit -1; }
  oc -n $ns get secret $secret -o yaml > /tmp/secret2.$uuid || { echo "[ERROR] $(date) Cannot find secret $secret in namespace $ns, hence exiting!"; $WORKDIR/restore/postgres/postgres-post-restore.sh; exit -1; }
  pod=$(oc -n $ns get clusters.postgresql.k8s.enterprisedb.io | grep -v '^NAME' | sed -e 's/.* //')
  [ -n "$2" ] && pod=$2
  oc -n $ns get pod $pod -o yaml > /tmp/server.$uuid || { echo "[ERROR] $(date) Cannot find pod $pod in namespace $ns hence exiting!"; $WORKDIR/restore/postgres/postgres-post-restore.sh; exit -1; }
  sa=$(grep serviceAccountName: /tmp/server.$uuid | awk '{print $2}')

  echo "[INFO] $(date) Add environment variables and copy file to container"
  cp $WORKDIR/restore/postgres/edb_backup_restore.sh /tmp/edb_backup_restore.sh.$uuid
  host=$(grep '^  host:' /tmp/secret1.$uuid | awk '{print $2}' | base64 -d)
  sed -i 's/type=/export POSTGRES_HOST='$host'\ntype=/' /tmp/edb_backup_restore.sh.$uuid
  port=$(grep '^  port:' /tmp/secret1.$uuid | awk '{print $2}' | base64 -d)
  sed -i 's/type=/export POSTGRES_PORT='$port'\ntype=/' /tmp/edb_backup_restore.sh.$uuid
  dbname=$(grep '^  dbname:' /tmp/secret2.$uuid | awk '{print $2}' | base64 -d)
  sed -i 's/type=/export POSTGRES_DBNAME='$dbname'\ntype=/' /tmp/edb_backup_restore.sh.$uuid
  username=$(grep '^  username:' /tmp/secret2.$uuid | awk '{print $2}' | base64 -d)
  sed -i 's/type=/export POSTGRES_USERNAME='$username'\ntype=/' /tmp/edb_backup_restore.sh.$uuid
  password=$(grep '^  password:' /tmp/secret2.$uuid | awk '{print $2}' | base64 -d)
  sed -i 's/type=/export POSTGRES_PASSWORD='$password'\ntype=/' /tmp/edb_backup_restore.sh.$uuid
  folder=$(grep -B1 pgdata /tmp/server.$uuid | grep mountPath | head -1 | sed -e 's/.* //')/backup/$dbname

  echo "[INFO] $(date) Restore database $dbname from file $dbname.dmp"
  {  # try
     oc exec -i -t $pod -n $ns -- mkdir -p $folder &&
     oc cp -n $ns backup-postgres:/usr/share/backup/$dbname/$dbname.tar /tmp/$dbname.tar &&
     oc cp -n $ns /tmp/$dbname.tar $pod:$folder/$dbname.tar &&
     oc exec $pod -n $ns -- bash -c "cd $folder && tar xvf $dbname.tar" &&
     oc exec $pod -n $ns -- bash -c "rm -f $folder/$dbname.tar" &&
     echo "[INFO] $(date) Backup file from  backup-postgres to postgres pod transferred!" 
  } || { # catch
     echo "[ERROR] $(date) Transfer of backup file to postgres pod failed, hence exiting!" && $WORKDIR/restore/postgres/postgres-post-restore.sh && exit 1
  }

  echo "[INFO] $(date) Performing EDB postgres db restore"
  oc cp /tmp/edb_backup_restore.sh.$uuid $pod:$folder/edb_backup_restore.sh -n $ns
  oc exec -i -t $pod -n $ns -- $folder/edb_backup_restore.sh restore $dbname
  result=$?
done

$WORKDIR/restore/postgres/postgres-post-restore.sh

[ $result -eq 0 ] && echo "[INFO] $(date) EDB Postgres restore is completed! The database $dbname was restored" && echo "[INFO] $(date) ############## EDB postgres restore completed ##############" && exit 0
echo "[ERROR] $(date) Failed to restore database $dbname hence exiting" && exit -1
