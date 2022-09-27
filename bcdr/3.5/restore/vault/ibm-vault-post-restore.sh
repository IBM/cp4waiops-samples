#!/bin/bash

echo "[INFO] $(date) ############## IBM Vault post-restore process has started ##############"

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
# Deleting ibm-vault-deploy-backup folder
rm -rf ibm-vault-deploy-backup 2> /dev/null
oc delete pod backup-other-resources -n $namespace 2> /dev/null
oc delete pvc other-resources-backup-data -n $namespace 2> /dev/null
