#!/bin/bash

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
MINIO_RC=$(cat minio-rc-data.json | jq -r '.MINIO_RC')
echo $namespace $MINIO_RC

# Deleting all minio backup pods
oc delete po -n $namespace -l minio.cp4aiops.ibm.com/backup=t

# Scaling up aimanager-ibm-minio sts
oc scale sts aimanager-ibm-minio -n $namespace --replicas=$MINIO_RC
