#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

source cassandra-utils.sh

echo "[INFO] $(date) Scaling up the ibm-ir-ai-operator-controller-manager deployment to original state"
RC=$(cat aiops-topology-rc-data.json | jq -r --arg deployementRC "ibm-ir-ai-operator-controller-manager-RC" '.[$deployementRC]')
oc scale deploy ibm-ir-ai-operator-controller-manager -n $namespace  --replicas=$RC

echo "[INFO] $(date) Scaling up the metric and topology deployment after Cassandra backup is completed"
deploymentList=$(oc get deployment -n $namespace --no-headers -o custom-columns=":metadata.name"|grep -i "aiops-topology\|aiops-ir-analytics"|grep -v cassandra)
for deployment in $deploymentList; do
    
    {
    #TRY
        RC=$(cat aiops-topology-rc-data.json | jq -r --arg deployementRC "$deployment-RC" '.[$deployementRC]')
        
    } || {
        RC=$(cat aiops-topology-rc-data.json | jq -r --arg deployementRC "$deployment-RC" '.[$deployementRC]')
    }
    echo "[INFO] $(date) Scaling up the deployment, $deployment to original replica count $RC" 
    oc scale deployment $deployment -n $namespace --replicas=$RC 
    
done
