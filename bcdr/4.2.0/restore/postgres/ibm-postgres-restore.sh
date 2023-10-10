#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

# We assume you have kubectl installed in the environment. And you already logged into the cluster as the admin.
# This scripts accepts four parameters: action, secret_name, pod_name, and storageclass_name.
# If the arguments are not supplied, the script will use the default values. The default values are only valid for ibm-postgresql.
echo "[INFO] $(date) ############## IBM postgres restore started ##############"

#set -x
BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/common-utils.sh
source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
ibmPostgresRestoreNamePrefix="ibm-postgres-restore"
ibmPostgresRestoreLabel="postgres.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, ibmPostgresRestoreNamePrefix: $ibmPostgresRestoreNamePrefix, ibmPostgresRestoreLabel: $ibmPostgresRestoreLabel"

echo "[INFO] $(date) Performing velero restore for IBM postgres"
performVeleroRestore $ibmPostgresRestoreNamePrefix $backupName $namespace $ibmPostgresRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence performing post restore steps for cleanup now before exit"
      $WORKDIR/restore/postgres/postgres-post-restore.sh
      exit 1
fi

# Check if required pvc is created through velero restore or not
checkPvcStatus $namespace "postgres-backup-data"
pvcCheckReturnValue=$?
if [ $pvcCheckReturnValue -ne 0 ]; then
    echo "[ERROR] $(date) PVC check has failed with return value $pvcCheckReturnValue"
    $WORKDIR/restore/postgres/postgres-post-restore.sh
    exit 1
fi

uuid=$(cat /proc/sys/kernel/random/uuid)

echo "[INFO] $(date) Collecting information"
#[ ! "$1" = "backup" ] && [ ! "$1" = "restore" ] && echo Action $1 is invalid, should be \'backup\' or \'restore\', exit ... && exit -1
#action="restore"

secret=cp4waiops-postgresdb-postgresql-cp4waiops-secret
[ -n "$2" ] && secret=$2
oc get secret -n $namespace $secret -o yaml > /tmp/secret.$uuid || { echo "[ERROR] $(date) Cannot find secret $secret in current namespace hence exiting!"; $WORKDIR/restore/postgres/postgres-post-restore.sh; exit -1; }

pod=cp4waiops-postgres-keeper-0
[ -n "$3" ] && pod=$3
oc get pod $pod -n $namespace -o yaml > /tmp/server.$uuid || { echo "[ERROR] $(date) Cannot find pod $pod in current namespace hence exiting!"; $WORKDIR/restore/postgres/postgres-post-restore.sh; exit -1; }

#namespace=$(grep namespace: /tmp/secret.$uuid | awk '{print $2}')
sa=$(grep serviceAccountName: /tmp/server.$uuid | awk '{print $2}')

echo "[INFO] $(date) Add environment variables and copy file to container"
cp $WORKDIR/restore/postgres/backup_restore.sh /tmp/backup_restore.sh.$uuid
host=$(grep '^  host:' /tmp/secret.$uuid | awk '{print $2}' | base64 -d)
sed -i 's/type=/export POSTGRES_HOST='$host'\ntype=/' /tmp/backup_restore.sh.$uuid
port=$(grep '^  port:' /tmp/secret.$uuid | awk '{print $2}' | base64 -d)
sed -i 's/type=/export POSTGRES_PORT='$port'\ntype=/' /tmp/backup_restore.sh.$uuid
dbname=$(grep '^  dbname:' /tmp/secret.$uuid | awk '{print $2}' | base64 -d)
sed -i 's/type=/export POSTGRES_DBNAME='$dbname'\ntype=/' /tmp/backup_restore.sh.$uuid
username=$(grep '^  username:' /tmp/secret.$uuid | awk '{print $2}' | base64 -d)
sed -i 's/type=/export POSTGRES_USERNAME='$username'\ntype=/' /tmp/backup_restore.sh.$uuid
password=$(grep '^  password:' /tmp/secret.$uuid | awk '{print $2}' | base64 -d)
sed -i 's/type=/export POSTGRES_PASSWORD='$password'\ntype=/' /tmp/backup_restore.sh.$uuid

#if [ "$action" = "restore" ]; then
echo "[INFO] $(date) Restore database $dbname from file $dbname.dmp"
#[ ! -f $dbname.dmp ] && echo Cannot find file $dbname.dmp, exit ... && exit -1
#kubectl exec -i -t $pod -- mkdir -p /home/stolon/backup/$dbname 1>/dev/null 2>&1 && kubectl cp $dbname.dmp $pod:/home/stolon/backup/$dbname/$dbname.dmp 1>/dev/null
{  # try
   oc exec -i -t $pod -n $namespace -- mkdir -p /home/stolon/backup/$dbname &&
   oc cp -n $namespace backup-postgres:/usr/share/backup/$dbname/$dbname.tar /tmp/$dbname.tar &&
   oc cp -n $namespace /tmp/$dbname.tar $pod:/home/stolon/backup/$dbname/$dbname.tar &&
   oc exec $pod -n $namespace -- bash -c "cd /home/stolon/backup/$dbname && tar xvf $dbname.tar" &&
   oc exec $pod -n $namespace -- bash -c "rm -f /home/stolon/backup/$dbname/$dbname.tar" &&
   echo "[INFO] $(date) Backup file from  backup-postgres to postgres pod transferred!" 
} || { # catch
   echo "[ERROR] $(date) Transfer of backup file to postgres pod failed, hence exiting!" && 
   $WORKDIR/restore/postgres/postgres-post-restore.sh && 
   exit 1
}

echo "[INFO] $(date) Performing IBM postgres db restore"
oc cp /tmp/backup_restore.sh.$uuid $pod:/tmp/backup_restore.sh -n $namespace
oc exec -i -t $pod -n $namespace -- /tmp/backup_restore.sh restore $dbname
result=$?

$WORKDIR/restore/postgres/postgres-post-restore.sh

[ $result -eq 0 ] && echo "[INFO] $(date) IBM Postgres restore is completed! The database $dbname was restored" && echo "[INFO] $(date) ############## IBM postgres restore completed ##############" && exit 0
echo "[ERROR] $(date) Failed to restore database $dbname hence exiting" && exit -1
