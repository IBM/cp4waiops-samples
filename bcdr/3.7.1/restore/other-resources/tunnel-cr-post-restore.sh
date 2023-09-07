#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

echo "[INFO] $(date) ############## IBM tunnel CR post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

echo "[WARNING] $(date) Deleting restored resources"
oc delete pod backup-other-resources -n $namespace 2> /dev/null
oc delete pvc other-resources-backup-data -n $namespace 2> /dev/null

