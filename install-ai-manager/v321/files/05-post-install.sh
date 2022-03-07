#!/usr/bin/env bash

source ./00-config.sh

GLOBAL_POD_VERIFY_STATUS=false

function processAiopsanalyticsorchestrators() {
  RESOURCE_COUNT=0
  RESOURCE_FOUND=false

  LOOP_COUNT=0
  MAX_LOOP_COUNT=120

  ## Verify whether aiopsanalyticsorchestrators got created, for every 5 seconds and retry for 120 times (10 minutes).
  echo "-----------------------------------"
  echo "1. Verify the creation of the resource : aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com/aiops"
  echo "-----------------------------------"

  while [[ ${RESOURCE_FOUND} == "false" && $LOOP_COUNT < $MAX_LOOP_COUNT ]]; do
      LOOP_COUNT=$((LOOP_COUNT+1))
      echo "Trying for $LOOP_COUNT / $MAX_LOOP_COUNT."

      RESOURCE_COUNT=$(oc get aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com/aiops -n cp4waiops | wc -l)

      if [[ $RESOURCE_COUNT -gt 1 ]]; 
      then
          RESOURCE_FOUND=true
      else
          RESOURCE_FOUND=false
          sleep 5
      fi
  done

  if [[ $RESOURCE_FOUND == "true" ]]; 
  then
      echo "Resource found (aiopsanalyticsorchestrators)"
      echo "Patch the operator with the pullsecret"
      oc patch aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com/aiops -n ${NAMESPACE} -p '{"spec":{"pullSecrets":["ibm-aiops-pull-secret"]}}' --type=merge -n ${NAMESPACE}

      echo " Sleep for 4 seconds"
      sleep 4

      echo " Delete Pods starts with the name : aiops-ir-analytics"
      oc get pods  -n  ${NAMESPACE} --no-headers=true | awk '/aiops-ir-analytics/{print $1}' | xargs  oc delete -n  ${NAMESPACE} pod
  else
      echo "Resource Not found (aiopsanalyticsorchestrators)"
  fi
}

## Verify Pods Count in WAIOps Namespace
function verifyAIOpsPodsCount() {
  echo "-----------------------------------"
  echo " 2. Verify Pods Count in WAIOps Namespace"
  echo "-----------------------------------"

  POD_COUNT=0
  MIN_POD_COUNT=110
  MAX_WAIT_MINUTES=120
  LOOP_COUNT=0
  
  while [[ $POD_COUNT -lt $MIN_POD_COUNT ]] && [[ $LOOP_COUNT -lt $MAX_WAIT_MINUTES ]]; do
    POD_COUNT=$(oc get pods -n $NAMESPACE | wc -l ) 
    echo "WAIOps Pod Count in $LOOP_COUNT minutes : $POD_COUNT"
    LOOP_COUNT=$((LOOP_COUNT + 1))
    sleep 60
  done

  if [[ $POD_COUNT -gt $MIN_POD_COUNT ]]; then
      echo "WAIOps Namespace Pods counts are OK and it is more than $MIN_POD_COUNT"; 
      GLOBAL_POD_VERIFY_STATUS=true
  else
    echo "Timed out waiting for PODs in ${NAMESPACE}"
    echo "Only $POD_COUNT pods are created in WAIOps namespace. It should be more than  $MIN_POD_COUNT"; 
    GLOBAL_POD_VERIFY_STATUS=false
  fi
}

## AutomationUIConfig , secret with AI Manager ingress certificate, Restarting nginx pod
function restartNginxPods() {
  echo "-----------------------------------"
  echo " 3. Restarting nginx pod, recreating AutomationUIConfig and create secret with AI Manager ingress certificate"
  echo "-----------------------------------"

  echo "3.1. Delete your AutomationUIConfig instance and quickly re-create it before the Installation operator automatically re-creates it"

  AUTO_UI_INSTANCE=$(oc get AutomationUIConfig -n $NAMESPACE --no-headers -o custom-columns=":metadata.name")
  IAF_STORAGE=$(oc get AutomationUIConfig -n $NAMESPACE -o jsonpath='{ .items[*].spec.storage.class }')
  oc delete -n $NAMESPACE AutomationUIConfig $AUTO_UI_INSTANCE


cat <<EOF | oc apply -f -
apiVersion: core.automation.ibm.com/v1beta1
kind: AutomationUIConfig
metadata:
  name: $AUTO_UI_INSTANCE
  namespace: $NAMESPACE
spec:
  description: AutomationUIConfig for cp4waiops
  license:
    accept: true
  version: v1.0
  storage:
    class: $IAF_STORAGE
  tls:
    caSecret:
      key: ca.crt
      secretName: external-tls-secret
    certificateSecret:
      secretName: external-tls-secret
EOF

  echo "3.2 Replace the existing secret with a secret that contains the AI Manager ingress certificate."

  # Get the certificate and key from AI Manager ingress.
  ingress_pod=$(oc get secrets -n openshift-ingress | grep tls | grep -v router-metrics-certs-default | awk '{print $1}')
  oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.crt"}}' ${ingress_pod} | base64 -d > cert.crt
  oc get secret -n openshift-ingress -o 'go-template={{index .data "tls.key"}}' ${ingress_pod} | base64 -d > cert.key

  # Back up the existing secret to a yaml file.
  oc get secret -n $NAMESPACE external-tls-secret -o yaml > external-tls-secret.yaml

  # Delete the existing secret.
  oc delete secret -n $NAMESPACE external-tls-secret

  # Create the new secret with the AI Manager ingress certificate. 
  oc create secret generic -n $NAMESPACE external-tls-secret --from-file=cert.crt=cert.crt --from-file=cert.key=cert.key --dry-run=client -o yaml | oc apply -f -

  echo "3.3 Restart NGINX Pods"

  # Scale down NGINX.
  REPLICAS=$(oc get pods -l component=ibm-nginx -n $NAMESPACE  -o jsonpath='{ .items[*].metadata.name }' | wc -w)
  ((REPLICAS=REPLICAS+0))
  oc scale Deployment/ibm-nginx --replicas=0 -n $NAMESPACE 
                                
  # Scale up nginx. The new NGINX pods get the new certificate. It takes a few minutes for the NGINX pods to come back up.
  sleep 3
  oc scale Deployment/ibm-nginx --replicas=${REPLICAS} -n $NAMESPACE 
}


## Main method
function postInstallMain() {
  ## Verify whether aiopsanalyticsorchestrators got created, for every 5 seconds and retry for 60 times.
  echo "----------------------------------------------------------------------"-----------------------------------
  echo "WAIOps Post Install Activities"
  echo "---------------------------------------------------------------------------------------------------------"

  ## Add the pull secret to the ibm-aiops-orchestrator operator.
  processAiopsanalyticsorchestrators

  ## Verify Pods Count in WAIOps Namespace
  verifyAIOpsPodsCount

  if [[ ${GLOBAL_POD_VERIFY_STATUS} == "true" ]]; then 
    ## AutomationUIConfig , secret with AI Manager ingress certificate, Restarting nginx pod
    restartNginxPods
  fi
}

## Call the Main method
postInstallMain