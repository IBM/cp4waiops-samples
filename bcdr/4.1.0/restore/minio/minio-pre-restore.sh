#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Getting the replica count before scaling down the required pods
MINIO_RC=$(oc get sts aimanager-ibm-minio -n $namespace -o=jsonpath='{.spec.replicas}')

echo "[WARNING] $(date) Deleting previously restored minio resources if exist"
oc delete po -n $namespace -l minio.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Before scaling down aimanager-ibm-minio statefulset replica count is $MINIO_RC"

#Saving the replica count values to a json file as it's required for post-restore script
JSON='{"MINIO_RC": '"$MINIO_RC"'}'
rm -f $WORKDIR/restore/minio/minio-rc-data.json
echo $JSON > $WORKDIR/restore/minio/minio-rc-data.json

echo "[WARNING] $(date) Scaling down the aimanager-ibm-minio sts"
oc scale sts aimanager-ibm-minio -n $namespace --replicas=0

echo "[WARNING] $(date) Deleting aimanager-ibm-minio-access-secret"
oc get secret  -n $namespace aimanager-ibm-minio-access-secret -o yaml > $WORKDIR/restore/minio/aimanager-ibm-minio-access-secret-pre-restore.yaml
oc delete secret -n $namespace aimanager-ibm-minio-access-secret

echo "[WARNING] $(date) Deleting all minio pvc's"
pvcList=$(oc get pvc -n $namespace | grep export-aimanager-ibm-minio- | cut -d " " -f1)
for pvc in $pvcList; do
    echo "[INFO] $(date) PVC name is $pvc"
    oc delete pvc -n $namespace $pvc
done
