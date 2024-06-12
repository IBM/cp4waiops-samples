#!/usr/bin/env bash

function patch_aiops_analytics_orchestrators () {

echo "-----------------------------------"
echo " 5. Verify the creation of the resource : aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com/aiops"
echo "-----------------------------------"

RESOURCE_COUNT=0
RESOURCE_FOUND=false
LOOP_COUNT=0
MAX_LOOP_COUNT=180

while [[ ${RESOURCE_FOUND} == "false" && $LOOP_COUNT -lt $MAX_LOOP_COUNT ]]; do
    LOOP_COUNT=$((LOOP_COUNT+1))
    echo "Trying for $LOOP_COUNT / $MAX_LOOP_COUNT."

    RESOURCE_COUNT=$(oc get aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com/aiops -n $NAMESPACE | wc -l)

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