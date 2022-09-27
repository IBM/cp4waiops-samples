#!/bin/bash
echo "[INFO] $(date) ############## CAM post restore process started ##############"

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')
CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC=$(cat cam-rc-data.json | jq '.CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC')
CAM_MONGO_RC=$(cat cam-rc-data.json | jq '.CAM_MONGO_RC')
echo "[INFO] $(date) namespace: $namespace, CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC: $CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC, CAM_MONGO_RC: $CAM_MONGO_RC"

echo "[WARNING] $(date) Deleting cam backup pod"
oc delete po -n $namespace -l cam.cp4aiops.ibm.com/backup=t

echo "[INFO] $(date) Scaling up cam-install-operator-controller-manager and cam-mongo deployments"
oc scale deployment cam-install-operator-controller-manager --replicas=$CAM_INSTALL_OPERATOR_CONTROLLER_MANAGER_RC -n $namespace
oc scale deployment cam-mongo --replicas=$CAM_MONGO_RC -n $namespace

echo "[INFO] $(date) ############## CAM post restore process completed ##############"
