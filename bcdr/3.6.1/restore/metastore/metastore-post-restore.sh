#!/bin/bash

echo "[INFO] $(date) ############## IBM Metastore post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

echo "[INFO] $(date) Deleting restored resources"
oc delete po -n $namespace -l metastore.cp4aiops.ibm.com/backup=t 2> /dev/null
oc delete pvc -n $namespace -l metastore.cp4aiops.ibm.com/backup=t 2> /dev/null
oc delete configmap metastore-bcdr-config -n $namespace 2> /dev/null
oc patch cronjobs zen-metastore-backup-cron-job -p '{"spec" : {"suspend" : false }}' -n $namespace 2> /dev/null
