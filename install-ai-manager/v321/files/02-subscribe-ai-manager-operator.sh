#!/usr/bin/env bash

function subscribe_ai_manager_operator() {

echo "-----------------------------------"
echo "2. Installing IBM Cloud Pak for Watson AIOps AI Manager - Subscribe to AI Manager operator started"
echo "-----------------------------------"


echo "2.1. Install  AI Manager operator"
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-aiops-orchestrator
  namespace: $NAMESPACE
spec:
  channel: v3.2
  installPlanApproval: Automatic
  name: ibm-aiops-orchestrator
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

sleep 5

echo "Process completed .... "

}