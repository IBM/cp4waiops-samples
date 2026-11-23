#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#
aiopsNamespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
aiopsVersion=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsVersion')

checkAiopsVersion() {
    versionCheckValue=0
    echo "[INFO] $(date) Checking AIOPS version before proceeding for BCDR operation"
    echo "[INFO] $(date)  Expected AIOPS version of cluster for BCDR operation is $aiopsVersion"
    aimanageroperatorCSV=$(kubectl get csv -n $aiopsNamespace --show-labels|grep -i aimanager-operator |cut -d " " -f 1)
    echo "[INFO] $(date) aimanager-operator CSV name is $aimanageroperatorCSV"
    currentVersion=$(kubectl get csv $aimanageroperatorCSV  -n $aiopsNamespace -o jsonpath='{.spec.install.spec.deployments[0].spec.template.metadata.annotations.cloudpakVersion}')
    echo "[INFO] $(date) Actual AIOPS version of cluster is $currentVersion"
    if [[ $aiopsVersion == $currentVersion ]]; then
        echo "[INFO] $(date) Expected and Actual versions of AIOPS cluster are same, hence proceeding for BCDR operation"
        return $versionCheckValue
    else
        echo "[ERROR] $(date) Expected and Actual versions of AIOPS cluster are different, hence aborting BCDR operation"
        versionCheckValue=1
	    return $versionCheckValue
    fi
}

