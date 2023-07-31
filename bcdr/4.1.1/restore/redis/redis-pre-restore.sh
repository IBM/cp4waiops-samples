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
REDIS_RC=$(oc get sts c-example-redis-m -n $namespace -o=jsonpath='{.spec.replicas}')

echo "[WARNING] $(date) Deleting previously restored redis resources if exist"
oc delete po -n $namespace -l redis.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Before scaling down c-example-redis-m statefulset replica count is $REDIS_RC"

#Saving the replica count values to a json file as it's required for post-restore script
JSON='{"REDIS_RC": '"$REDIS_RC"'}'
rm -f $WORKDIR/restore/redis/redis-rc-data.json
echo $JSON > $WORKDIR/restore/redis/redis-rc-data.json

echo "[WARNING] $(date) Scaling down the c-example-redis-m sts"
oc scale sts c-example-redis-m -n $namespace --replicas=0

echo "[WARNING] $(date) Deleting c-example-redis-m"
oc get secret  -n $namespace c-example-redis-m -o yaml > $WORKDIR/restore/redis/c-example-redis-m-pre-restore.yaml
oc delete secret -n $namespace c-example-redis-m

echo "[WARNING] $(date) Deleting all redis pvc's"
pvcList=$(oc get pvc -n $namespace | grep data-c-example-redis-m- | cut -d " " -f1)
for pvc in $pvcList; do
    echo "[INFO] $(date) PVC name is $pvc"
    oc delete pvc -n $namespace $pvc
done