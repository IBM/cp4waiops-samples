#!/bin/bash



#Checking if the required AIOPS Pods are in running state
aiopsPodStatus() {
    namespace=$1
    aiops_pods_label=$(cat ../common/prereq-check-details.json | jq -r  .aiopspodsLabel[].podlabel)
    for label in $aiops_pods_label; do
        podList=$(oc get pods -l $label -n $namespace --no-headers=true --output=custom-columns=NAME:.metadata.name)
        if [ -z "$podList" ]; then
            echo "No pod found with label $label, hence exiting"
            exit 1
        fi
        for pod in $podList; do
            status1=$(oc get pod $pod -n $namespace -o=jsonpath='{.status.phase}')
            status2=$(oc get pod $pod -n $namespace -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [[  $status1 != "Running"  ]] || [[ $status2 != "True" ]]; then
                echo "Pod $pod is not in running/ready state, hence exiting"
                exit 1
            else 
                echo "Pod $pod is in $status1 and Ready state now"
            fi
        done
    done
}

#Checking if the required AIOPS PVC status is in bound state
checkPvcStatus(){
    pvcNamespace=$1
    pvcName=$2
    echo "Checking if $pvcName PVC is created and in bound state...."
    pvc_name=$(oc get pvc  -n $pvcNamespace --no-headers=true --output=custom-columns=NAME:.metadata.name | grep $pvcName)
    if [ -z "$pvc_name" ]; then
        echo "No pvc found with name $pvcName, hence aborting the execution of further steps!"
        exit 1
    else
        echo "pvc found is $pvc_name"
    fi
    for pvc in $pvc_name; do
    	pvc_state=$(oc get pvc $pvc -n $pvcNamespace -o=jsonpath='{.status.phase}')
    	if [[  $pvc_state != "Bound"  ]]; then
        	echo "pvc $pvc is not in bound state, current status is $pvc_state, hence aborting the execution of further steps!"
        	exit 1
    	else
        	echo "pvc $pvc is in $pvc_state state!"
    	fi
    done
}

#Check if CP4WAIOPS is in good and running state
aiopsStatus(){
    namespace=$1
    echo "Check Installation orchestrator status...."
    installorchestrator_status=$(oc get installations.orchestrator.aiops.ibm.com -n $namespace -o=jsonpath='{.items[0].status.phase}') #Running
    if [[  $installorchestrator_status != "Running"  ]]; then
        echo "Installation orchestrator is not in running phase, current phase is  $installorchestrator_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "Installation orchestrator is in $installorchestrator_status phase"
    fi

    echo "Checking ircore status...."
    ircore_status=$(oc get ircore -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}') #Ready
    if [[  $ircore_status != "Ready"  ]]; then
        echo "ircore is not in ready state, current status is $ircore_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "ircore is in $ircore_status state"
    fi

    echo "Checking AIOpsAnalyticsOrchestrator status...."
    aiopsanalyticsorchestrator_status=$(oc get  AIOpsAnalyticsOrchestrator -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}')  #Ready
    if [[  $aiopsanalyticsorchestrator_status != "Ready"  ]]; then
        echo "AIOpsAnalyticsOrchestrator is not in ready state, current status is $aiopsanalyticsorchestrator_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "AIOpsAnalyticsOrchestrator is in $aiopsanalyticsorchestrator_status state"
    fi

    echo "Checking lifecycleservice status...."
    lifecycleservice_status=$(oc get lifecycleservice -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Lifecycle Service Ready")].reason}') #Ready
    if [[  $lifecycleservice_status != "Ready"  ]]; then
        echo "lifecycleservice is not in ready state, current status is $lifecycleservice_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "lifecycleservice is in $lifecycleservice_status state"
    fi

    echo "Checking BaseUI status...."
    baseui_status=$(oc get BaseUI -n $namespace -o=jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].reason}')  #Ready
    if [[  $baseui_status != "Ready"  ]]; then
        echo "BaseUI is not in ready state, current status is $baseui_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "BaseUI is in $baseui_status state"
    fi

    echo "Checking AIManager status...."
    aimanager_status=$(oc get AIManager -n $namespace -o=jsonpath='{.items[0].status.phase}') #Completed
    if [[  $aimanager_status != "Completed"  ]]; then
        echo "AIManager is not in Completed state, current status is $aimanager_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "AIManager is in $aimanager_status state"
    fi

    echo "Checking aiopsedge status...."
    aiopsedge_status=$(oc get aiopsedge -n $namespace -o=jsonpath='{.items[0].status.phase}') #Configured
    if [[  $aiopsedge_status != "Configured"  ]]; then
        echo "aiopsedge is not in Configured state, current status is $aiopsedge_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "aiopsedge is in $aiopsedge_status state"
    fi


    echo "Checking asm status...."
    asm_status=$(oc get asm -n $namespace -o=jsonpath='{.items[0].status.phase}') #OK
    if [[  $asm_status != "OK"  ]]; then
        echo "asm is not in OK state, current status is $asm_status, hence aborting the execution of further steps!"
        exit 1
    else
        echo "asm is in $asm_status state"
    fi

    echo "This CP4WAIOPS cluster is in good state,lets proceed...."
}

