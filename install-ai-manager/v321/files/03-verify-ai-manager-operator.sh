#!/usr/bin/env bash

function verify_ai_manager_operator() {

echo "-----------------------------------"
echo "3. Installing IBM Cloud Pak for Watson AIOps AI Manager - Verify AI Manager operator subscription"
echo "-----------------------------------"

echo "3.1. Verify the AI Manager operator installation..."

echo "Executing the below command ...."
echo "oc get pods -n $NAMESPACE | grep ibm-aiops-orchestrator."
echo "The output could be like this...."
echo "ibm-aiops-orchestrator-6c7cfc85b7-j9c92                           1/1     Running   0          6m27s"

export GLOBAL_POD_VERIFY_STATUS=false

RESOURCE_COUNT=0
RESOURCE_FOUND=false
LOOP_COUNT=0
MAX_LOOP_COUNT=180

while [[ ${RESOURCE_FOUND} == "false" && $LOOP_COUNT -lt $MAX_LOOP_COUNT ]]; do
    LOOP_COUNT=$((LOOP_COUNT+1))
    echo "Trying for $LOOP_COUNT / $MAX_LOOP_COUNT."

    RESOURCE_COUNT=$(oc get pods -n ${NAMESPACE} | grep ibm-aiops-orchestrator | grep -c Running)

    if [[ $RESOURCE_COUNT -gt 0 ]]; 
    then
        RESOURCE_FOUND=true
    else
        RESOURCE_FOUND=false
        sleep 5
    fi
done

if [[ $RESOURCE_FOUND == "true" ]]; 
then
    echo "Resource found (ibm-aiops-orchestrator pod)"
    export GLOBAL_POD_VERIFY_STATUS=true
else
    echo "Resource Not found (ibm-aiops-orchestrator pod). Terminating.. Retry the install "
    export GLOBAL_POD_VERIFY_STATUS=false
fi


echo "STATS11: ${GLOBAL_POD_VERIFY_STATUS} "


echo "Process completed .... "

}