#!/bin/bash

echo "[INFO] $(date) ############## Postgres post-restore process has started ##############"
source $WORKDIR/common/common-utils.sh
namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

echo "[INFO] $(date) Deleting restored resources"
oc delete pod backup-postgres -n $namespace 2> /dev/null
oc delete pvc postgres-backup-data -n $namespace 2> /dev/null

echo "[INFO] $(date) Restarting aimanager-aio-controller pod after postgres restore"
oc delete pod -l app.kubernetes.io/component=controller -n $namespace

echo "[INFO] $(date) Waiting for sometime after restarting aimanager-aio-controller pod"
wait "60"
# Wait till aimanager-aio-controller pod comes up and running"
checkPodReadyness $namespace "app.kubernetes.io/component=controller" "60"

