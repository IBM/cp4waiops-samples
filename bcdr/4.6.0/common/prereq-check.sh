#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#



#Checking if the required AIOPS Pods are in running state
aiopsPodStatus() {
    namespace=$1
    podCheckValue=0
    aiops_pods_label=$(cat $WORKDIR/common/prereq-check-details.json | jq -r  .aiopspodsLabel[].podlabel)
    for label in $aiops_pods_label; do
        podList=$(kubectl get pods -l $label -n $namespace --no-headers=true --output=custom-columns=NAME:.metadata.name)
        if [ -z "$podList" ]; then
            echo "[ERROR] $(date) No pod found with label $label, hence exiting"
	    podCheckValue=1
	    return $podCheckValue
            #exit 1
        fi
        for pod in $podList; do
            status1=$(kubectl get pod $pod -n $namespace -o=jsonpath='{.status.phase}')
            status2=$(kubectl get pod $pod -n $namespace -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [[  $status1 != "Running"  ]] || [[ $status2 != "True" ]]; then
                echo "[ERROR] $(date) Pod $pod is not in running/ready state, hence exiting"
                podCheckValue=1
		return $podCheckValue
		#exit 1
            else 
                echo "[INFO] $(date) Pod $pod is in $status1 and Ready state now"
            fi
        done
    done
}

#Checking if the required AIOPS PVC status is in bound state
checkPvcStatus(){
    pvcNamespace=$1
    pvcName=$2
    pvcCheckValue=0
    echo "[INFO] $(date) Checking if $pvcName PVC is created and in bound state"
    pvc_name=$(kubectl get pvc  -n $pvcNamespace --no-headers=true --output=custom-columns=NAME:.metadata.name | grep $pvcName)
    if [ -z "$pvc_name" ]; then
        echo "[ERROR] $(date) No pvc found with name $pvcName, hence aborting the execution of further steps!"
        pvcCheckValue=1
	return $pvcCheckValue
	#exit 1
    else
        echo "[INFO] $(date) pvc found is $pvc_name"
    fi
    for pvc in $pvc_name; do
    	pvc_state=$(kubectl get pvc $pvc -n $pvcNamespace -o=jsonpath='{.status.phase}')
    	if [[  $pvc_state != "Bound"  ]]; then
        	echo "[ERROR] $(date) pvc $pvc is not in bound state, current status is $pvc_state, hence aborting the execution of further steps!"
        	pvcCheckValue=1
		return $pvcCheckValue
		#exit 1
    	else
        	echo "[INFO] $(date) pvc $pvc is in $pvc_state state!"
    	fi
    done
}

#Check if CP4WAIOPS is in good and running state
aiopsStatus(){
    namespace=$1
    aiopsCheckValue=0
    echo "[INFO] $(date) Check Installation orchestrator status"
    installorchestrator_status=$(kubectl get installations.orchestrator.aiops.ibm.com -n $namespace -o=jsonpath='{.items[0].status.phase}') #Running
    if [[  $installorchestrator_status != "Running"  ]]; then
        echo "[ERROR] $(date) Installation orchestrator is not in running phase, current phase is $installorchestrator_status, hence aborting the execution of further steps!"
        #exit 1
	aiopsCheckValue=1
	return $aiopsCheckValue
    else
        echo "[INFO] $(date) Installation orchestrator is in $installorchestrator_status phase"
    fi

    echo "Checking ircore status...."
    ircore_status=$(kubectl get ircore -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}') #Ready
    if [[  $ircore_status != "Ready"  ]]; then
        echo "[ERROR] $(date) ircore is not in ready state, current status is $ircore_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) ircore is in $ircore_status state"
    fi

    echo "[INFO] $(date) Checking AIOpsAnalyticsOrchestrator status"
    aiopsanalyticsorchestrator_status=$(kubectl get  AIOpsAnalyticsOrchestrator -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}')  #Ready
    if [[  $aiopsanalyticsorchestrator_status != "Ready"  ]]; then
        echo "[ERROR] $(date) AIOpsAnalyticsOrchestrator is not in ready state, current status is $aiopsanalyticsorchestrator_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) AIOpsAnalyticsOrchestrator is in $aiopsanalyticsorchestrator_status state"
    fi

    echo "Checking lifecycleservice status"
    lifecycleservice_status=$(kubectl get lifecycleservice -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="LifecycleServiceReady")].reason}') #Ready
    if [[  $lifecycleservice_status != "Ready"  ]]; then
        echo "[ERROR] $(date) lifecycleservice is not in ready state, current status is $lifecycleservice_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) lifecycleservice is in $lifecycleservice_status state"
    fi

    echo "[INFO] $(date) Checking BaseUI status"
    baseui_status=$(kubectl get BaseUI -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}')  #Ready
    if [[  $baseui_status != "Ready"  ]]; then
        echo "[ERROR] $(date) BaseUI is not in ready state, current status is $baseui_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) BaseUI is in $baseui_status state"
    fi

    echo "[INFO] $(date) Checking AIManager status"
    aimanager_status=$(kubectl get AIManager -n $namespace -o=jsonpath='{.items[0].status.phase}') #Completed
    if [[  $aimanager_status != "Completed"  ]]; then
        echo "[ERROR] $(date) AIManager is not in Completed state, current status is $aimanager_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) AIManager is in $aimanager_status state"
    fi

    echo "[INFO] $(date) Checking aiopsedge status"
    aiopsedge_status=$(kubectl get aiopsedge -n $namespace -o=jsonpath='{.items[0].status.phase}') #Configured
    if [[  $aiopsedge_status != "Configured"  ]]; then
        echo "[ERROR] $(date) aiopsedge is not in Configured state, current status is $aiopsedge_status, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) aiopsedge is in $aiopsedge_status state"
    fi


    echo "[INFO] $(date) Checking asm status"
    asmCR=$(kubectl get asm -n $namespace | cut -d " " -f 1 | grep -v "NAME")
    asm_status=$(kubectl get asm $asmCR -n $namespace -o go-template='{{range .status.conditions}}{{if eq .type "CassandraReady"}}{{.status}}{{end}}{{if eq .type "DeploymentsReady"}}{{.status}}{{end}}{{end}}') #TrueTrue
    #asm_status=$(kubectl get asm -n $namespace -o=jsonpath='{.items[0].status.phase}') #OK
    if [[  $asm_status != "TrueTrue"  ]]; then
        echo "[ERROR] $(date) asm is not in OK state, current status is $asm_status for CassandraReady and DeploymentsReady, hence aborting the execution of further steps!"
        aiopsCheckValue=1
        return $aiopsCheckValue
	#exit 1
    else
        echo "[INFO] $(date) Current status for ASM is $asm_status for CassandraReady and DeploymentsReady"
    fi

    echo "[INFO] $(date) This CP4WAIOPS cluster is in good state,lets proceed"
}

#Check if any backup job running
backupJobStatus(){
    velero_namespace=$1
    echo "[INFO] $(date) Checking if there is any other backup job running on this cluster"
    kubectl get configmap backup-job-execution -n $velero_namespace
    if [ $? -eq 0 ]; then
        status=$(kubectl get configmap backup-job-execution -o=jsonpath='{.data.status}' -n $velero_namespace)
        echo "[INFO] $(date) Previous backup job execution status is $status"
        if [[ $status == "InProgress" ]]; then
            echo "[WARNING] $(date) There is already a backup job running, hence terminating this backup opertaion"
            exit 1
        else
            echo "[INFO] $(date) Previous backup job execution status is $status, hence starting the new backup operation"
            kubectl patch configmap backup-job-execution -p '{"data": {"status": "InProgress"}}' -n $velero_namespace
        fi
    else
        echo "[INFO] $(date) There is no details found for any earlier backup job on this cluster, hence starting the new backup operation"
        kubectl create configmap backup-job-execution --from-literal=status=InProgress -n $velero_namespace
    fi
}
