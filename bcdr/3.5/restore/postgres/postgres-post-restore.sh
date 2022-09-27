#!/bin/bash

echo "[INFO] $(date) ############## Postgres post-restore process has started ##############"

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

echo "[INFO] $(date) Deleting restored resources"
oc delete pod backup-postgres -n $namespace 2> /dev/null
oc delete pvc postgres-backup-data -n $namespace 2> /dev/null
