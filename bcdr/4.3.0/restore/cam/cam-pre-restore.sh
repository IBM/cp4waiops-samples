#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

source $WORKDIR/common/common-utils.sh
echo "[INFO] $(date) ############## CAM pre restore process started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

# Getting the replica count before scaling down the required pods
CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC=$(oc get deploy cam-install-operator-controller-manager -n $namespace -o=jsonpath='{.spec.replicas}')
echo "[INFO] $(date) Before scaling down cam-install-operator-controller-manager deployment replica count is $CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC"
CAM_MONGO_RC=$(oc get deploy cam-mongo -n $namespace -o=jsonpath='{.spec.replicas}')
echo "[INFO] $(date) Before scaling down cam-mongo deployment replica count is $CAM_MONGO_RC"

# Saving the replica count values to a json file as it's required for post-restore script
JSON='{"CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC": '"$CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC"', "CAM_MONGO_RC": '"$CAM_MONGO_RC"'  }'
rm -f $WORKDIR/restore/cam/cam-rc-data.json
echo $JSON > $WORKDIR/restore/cam/cam-rc-data.json

echo "[WARNING] $(date) Scaling down the cam-install-operator-controller-manager cam-mongo deployments to 0"
oc scale deployment cam-install-operator-controller-manager --replicas=0 -n $namespace
echo "[INFO] $(date) Waiting for sometime after scaling down cam-install-operator-controller-manager"
wait "60"
oc scale deployment cam-mongo --replicas=0 -n $namespace

echo "[WARNING] $(date) Deleting cam-secure-values-secret before restore"
oc get secret  -n $namespace cam-secure-values-secret -o yaml > $WORKDIR/restore/cam/cam-secure-values-secret-pre-restore.yaml
oc delete secret -n $namespace cam-secure-values-secret

echo "[WARNING] $(date) Deleting cam-mongo pvc"
oc delete pvc cam-mongo-pv -n $namespace

echo "[INFO] $(date) ############## CAM pre restore process completed ##############"
