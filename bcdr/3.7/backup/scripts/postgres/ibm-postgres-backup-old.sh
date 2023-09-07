#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

# We assume you have oc installed in the environment. And you already logged into the cluster as the admin.
# This scripts accepts four parameters: action, secret_name, pod_name, and storageclass_name.
# If the arguments are not supplied, the script will use the default values. The default values are only valid for ibm-postgresql.

#set -x
# create backup pod and volume to export data outside the cluster
echo "[INFO] $(date) ############## IBM Postgres backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/common-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
uuid=$(cat /proc/sys/kernel/random/uuid)

echo "[INFO] $(date) Collecting information"
#[ ! "$1" = "backup" ] && [ ! "$1" = "restore" ] && echo Action $1 is invalid, should be \'backup\' or \'restore\', exit ... && exit -1
#action="backup"

secret=cp4waiops-postgresdb-postgresql-cp4waiops-secret
[ -n "$2" ] && secret=$2
oc get secret $secret -n $namespace  -o yaml > /tmp/secret.$uuid || { echo Cannot find secret $secret in current namespace, exit ...; exit -1; }

pod=cp4waiops-postgres-keeper-0
[ -n "$3" ] && pod=$3
oc get pod $pod -n $namespace  -o yaml > /tmp/server.$uuid || { echo Cannot find pod $pod in current namespace, exit ...; exit -1; }

#namespace=$(grep namespace: /tmp/secret.$uuid | awk '{print $2}')
sa=$(grep serviceAccountName: /tmp/server.$uuid | awk '{print $2}')

echo "[INFO] $(date) Add environment variables and copy file to container"
cp backup_restore.sh /tmp/backup_restore.sh.$uuid
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

#if [ "$action" = "backup" ]; then
echo "[INFO] $(date) Back up database $dbname"
oc cp /tmp/backup_restore.sh.$uuid $pod:/tmp/backup_restore.sh -n $namespace
oc exec -i -t $pod -n $namespace  -- /tmp/backup_restore.sh backup $dbname
result=$?
[ $result -ne 0 ] && echo "[ERROR] $(date) Failed to back up database $dbname hence exiting!" && exit -1
#oc cp $pod:/home/stolon/backup/$dbname/$dbname.dmp ./$dbname.dmp 1>/dev/null && [ -f ./$dbname.dmp ] && echo Done! Database $dbname is backed up to $dbname.dmp. && exit 0

echo "[INFO] $(date) Creating postgres backup pod and pvc"
oc create -f postgres-backup.yaml -n $namespace

# Make sure backup-postgres is running
echo "[INFO] $(date) Checking if backup-postgres is running"
checkPodReadyness $namespace "component=backup-postgres" "60"

{  # try
   oc exec -i -t backup-postgres -n $namespace -- mkdir -p /usr/share/backup/$dbname &&
   oc exec $pod -n $namespace -- bash -c "cd /home/stolon/backup/$dbname && tar cf $dbname.tar $dbname.dmp" &&
   oc cp -n $namespace $pod:/home/stolon/backup/$dbname/$dbname.tar /tmp/$dbname.tar &&
   oc cp -n $namespace /tmp/$dbname.tar backup-postgres:/usr/share/backup/$dbname/$dbname.tar &&
   echo "[INFO] $(date) Backup file from postgres pod to backup-postgres pod transferred!" 
} || { # catch
   echo "[ERROR] $(date) Transfer of backup file to backup-postgres pod failed, hence exiting!"
   echo "[WARNING] $(date) Deleting postgres backup pod and pvc"
   oc delete -f postgres-backup.yaml -n $namespace
   exit 1
}

#fi
echo "[INFO] $(date) ############## IBM Postgres backup completed ##############"
