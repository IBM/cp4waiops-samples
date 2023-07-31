#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

echo "[INFO] $(date) ############## IBM common-services post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.csNamespace')

echo "[INFO] $(date) Deleting restored resources"
oc delete po dummy-db -n $namespace 2> /dev/null
oc delete po cleanup-pod -n $namespace 2> /dev/null
oc delete job icp-mongodb-restore -n $namespace 2> /dev/null
oc delete pvc my-mongodump -n $namespace 2> /dev/null
oc delete cm cs-bcdr-config -n $namespace 2> /dev/null
