#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

echo "[INFO] $(date) ############## IBM Minio post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
MINIO_RC=$(cat $WORKDIR/restore/minio/minio-rc-data.json | jq -r '.MINIO_RC')
echo "[INFO] $(date) namespace: $namespace, MINIO_RC: $MINIO_RC"

echo "[WARNING] $(date) Deleting all minio backup pods"
oc delete po -n $namespace -l minio.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up aimanager-ibm-minio sts"
oc scale sts aimanager-ibm-minio -n $namespace --replicas=$MINIO_RC

echo "[INFO] $(date) Restarting aiops-ir-ui-api-graphql pod"
oc delete po -n $namespace -l component=aiops-ir-ui-api-graphql
