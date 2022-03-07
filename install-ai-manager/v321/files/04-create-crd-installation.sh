#!/usr/bin/env bash

function create_crd_installation () {


echo "-----------------------------------"
echo "4. Installing IBM Cloud Pak for Watson AIOps AI Manager - Creating CRD Installation started"
echo "-----------------------------------"

echo "4.1. Install CRD Installation ..."

cat << EOF | oc apply -f -
apiVersion: orchestrator.aiops.ibm.com/v1alpha1
kind: Installation
metadata:
  name: ibm-cp-watson-aiops
  namespace: $NAMESPACE
spec:
  imagePullSecret: ibm-entitlement-key
  license:
    accept: true
  pakModules:
  - name: aiopsFoundation
    enabled: true
  - name: applicationManager
    enabled: true
  - name: aiManager
    enabled: true
  - name: connection
    enabled: false
  size: small
  storageClass: ibmc-file-gold-gid
  storageClassLargeBlock: ibmc-file-gold-gid
EOF

echo "Process completed .... "

}