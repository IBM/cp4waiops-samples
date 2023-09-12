#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

echo "[INFO] $(date) ############## IBM Redis post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
REDIS_RC=$(cat $WORKDIR/restore/redis/redis-rc-data.json | jq -r '.REDIS_RC')
echo "[INFO] $(date) namespace: $namespace, REDIS_RC: $REDIS_RC"

echo "[WARNING] $(date) Deleting all Redis backup pods"
oc delete po -n $namespace -l redis.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up c-example-redis-m sts"
oc scale sts c-example-redis-m -n $namespace --replicas=$REDIS_RC