#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

# We assume you have oc installed in the environment. And you already logged into the cluster as the admin.
# This scripts accepts two parameters: secret, pod.
# If the arguments are not supplied, the script will use default values.

#set -x
echo "[INFO] $(date) ############## EDB Postgres backup started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT
source $WORKDIR/common/common-utils.sh
install=$(oc get installations.orchestrator.aiops.ibm.com --all-namespaces | grep -v '^NAMESPACE')
ns=$(echo $install | awk '{print $1}')
installation=$(echo $install | awk '{print $2}')

secrets=$(cat $WORKDIR/common/postgres-db-secrets.json | jq -r '.[]')
for secret in $secrets; do
  uuid=$(cat /proc/sys/kernel/random/uuid)
  edbPostgresBackup="false"
  echo "[INFO] $(date) Collecting information"
  #secret=aimanager-edb-postgresdb-secret
  #[ -n "$1" ] && secret=$1
  oc -n $ns get secret $installation-edb-secret -o yaml > /tmp/secret1.$uuid || { echo Cannot find secret $installation-edb-secret in namespace $ns, exit ...; exit -1; }
  oc -n $ns get secret $secret -o yaml > /tmp/secret2.$uuid || { echo Cannot find secret $secret in namespace $ns, exit ...; exit -1; }
  pod=$(oc -n $ns get clusters.postgresql.k8s.enterprisedb.io | grep -v '^NAME' | sed -e 's/.* //')
  [ -n "$2" ] && pod=$2
  oc -n $ns get pod $pod -o yaml > /tmp/server.$uuid || { echo Cannot find pod $pod in namespace $ns, exit ...; exit -1; }
  sa=$(grep serviceAccountName: /tmp/server.$uuid | awk '{print $2}')

  echo "[INFO] $(date) Add environment variables and copy file to container"
  cp edb_backup_restore.sh /tmp/edb_backup_restore.sh.$uuid
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

  echo "[INFO] $(date) Back up database $dbname"
  oc exec -i -t $pod -n $ns -- mkdir -p $folder
  oc cp /tmp/edb_backup_restore.sh.$uuid $pod:$folder/edb_backup_restore.sh -n $ns
  oc exec -i -t $pod -n $ns  -- $folder/edb_backup_restore.sh backup $dbname
  result=$?
  [ $result -ne 0 ] && echo "[ERROR] $(date) Failed to back up database $dbname hence exiting!" && exit -1
  
  if [ "$secret" = "aimanager-edb-postgresdb-secret" ]; then
    echo "[INFO] $(date) Creating postgres backup pod and pvc"
    oc create -f postgres-backup.yaml -n $ns
    # Make sure backup-postgres is running
    echo "[INFO] $(date) Checking if backup-postgres is running"
    checkPodReadyness $ns "component=backup-postgres" "60"
  fi

  echo "[INFO] $(date) Copy dmp file"
  {  # try
     oc exec -i -t backup-postgres -n $ns -- mkdir -p /usr/share/backup/$dbname &&
     oc exec $pod -n $ns -- bash -c "cd $folder && tar cf $dbname.tar $dbname.dmp" &&
     oc cp -n $ns $pod:$folder/$dbname.tar /tmp/$dbname.tar &&
     oc cp -n $ns /tmp/$dbname.tar backup-postgres:/usr/share/backup/$dbname/$dbname.tar &&
     echo "[INFO] $(date) Backup file from postgres pod to backup-postgres pod transferred!" &&
     edbPostgresBackup="true"
  } || { # catch
     echo "[ERROR] $(date) Transfer of backup file to backup-postgres pod failed, hence exiting!"
     echo "[WARNING] $(date) Deleting postgres backup pod and pvc"
     oc delete -f postgres-backup.yaml -n $ns
     exit 1
  }
done

# Updating the backup result for EDB-postgres
if [[ $edbPostgresBackup == "true" ]]; then
   jq '.edbPostgresBackupStatus.nativebackup = true' /tmp/backup-result.json > tmp.$$.json && mv tmp.$$.json /tmp/backup-result.json
fi

echo "[INFO] $(date) ############## EDB Postgres backup completed ##############"
