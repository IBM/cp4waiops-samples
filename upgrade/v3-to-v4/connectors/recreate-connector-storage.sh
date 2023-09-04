#!/usr/bin/env bash
#
# Copyright 2023 IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
set -euo pipefail
# set -o xtrace # Uncomment for debugging.

# ---------- Defaults -------------------
: ${AWK:=awk}
: ${ALL_CONNECTORS:=false}
: ${CONNECTION_NAME:=""}

# ---------- Command functions ----------
function usage() {
	local script="${0##*/}"

	while read -r ; do echo "${REPLY}" ; done <<-EOF
	Usage: ${script} [OPTION]...
	Recreate Connector Storage

	Options:
	Mandatory arguments to long options are mandatory for short options too.
      -h, --help                    Display this help and exit
      -n, --namespace               The namespace where AIOps is installed. (Mandatory)
      -c, --connection              The ConnectorConfiguration name to update storage. This option is ignored if "-a/--all" option is set.
      -a, --all                     Recreate for all existing connectors
EOF
}


function toggleDataFlow() {
    local conn=${1}
    local toggle=${2}
    
    if [[ $toggle == "off" ]]; then
        value="false"
        msg "Disable connector data flow"
    else
        value="true"
        msg "Enable connector data flow"
    fi
    if [[ $connconfigType == "netcool-connector" ]]; then
        if [[ $(oc get connectorconfiguration $connconfig -o jsonpath='{.spec.config.collectAlerts}') != "$value" ]]; then
            patch="'{\"spec\":{\"config\":{\"collectAlerts\": $value}}}'"
            CMD="oc patch connectorconfiguration $connconfig --type='merge' -p $patch"
            printAndExecute "$CMD"
            doSleep="true"
        fi
    else
        if [[ $(oc get connectorconfiguration $connconfig -o jsonpath='{.spec.config.enableDataFlow}') != "$value" ]]; then
            patch="'{\"spec\":{\"config\":{\"enableDataFlow\": $value}}}'"
            CMD="oc patch connectorconfiguration $connconfig --type='merge' -p $patch"
            printAndExecute "$CMD"
            doSleep="true"
        fi
    fi
    if [[ ${doSleep:-} == "true" ]]; then
        info "Giving time for connector to pause or resume data flow" 
        sleep 30
    fi
}


function getDataFromStorage(){
    title "Checking connector storage for data extraction."

    # initialize
    proceedRecreate=false
    backupDataRequired=false

    if [[ $gitappStatus != "Configured" ]]; then
        # Check for specific error when an upgrade changes an immutable field.
        msg "Checking for error updating connector resources ..."
        info "Events for GitApp: $gitappName"
        CMD="oc get event --namespace $NS --field-selector involvedObject.name=$gitappName,type==Warning"
        printAndExecute "$CMD"
        backupDataRequired=true
        if [ $($CMD -o json | jq '.items[] | select(.message | test("Forbidden: updates to statefulset spec for fields other than.*")) | .message' | wc -l) -gt 0 ]; then
            msg "\"Unable to update Statefulset error\" event found."
            proceedRecreate=true
        else
            warning "WARNING: Did not find any event that indicate Statefulset update error occurred because the event may have rolled. Proceeding anyway ..."
        fi
    else
        msg "GitApp: $gitappName status is $gitappStatus"
        backupDataRequired=false
    fi

    connectorPvc=$(oc get pvc --namespace $NS --no-headers -l instance=connector-$connconfigUid -o jsonpath='{.items[*].metadata.name}')
    if [[ -z $connectorPvc ]]; then
        echo "Connector does not use storage."
        backupDataRequired=false
        return
    fi

    msg "Connector PVC: $connectorPvc"
    pvcAccessMode=$(getStorageAccessMode $connectorPvc)
    if [[ $pvcAccessMode =~ ReadWriteOnce ]]; then
        echo "Connector storage access mode is already using ReadWriteOnce (RWO)."
        backupDataRequired=false
        proceedRecreate=false;
        return
    fi

    if [[ $backupDataRequired != "true" ]]; then
        msg "No need to extract data from PVC"
        return;
    fi

    connectorPod=$(oc get pod --namespace $NS --no-headers -l instance=connector-$connconfigUid -o jsonpath='{.items[*].metadata.name}')

    # Get the data file path
    connectorWorkload=$(oc get statefulset --namespace $NS --no-headers -l connectors.aiops.ibm.com/git-app-name=$gitappName -o jsonpath='{.items[*].metadata.name}')

    if [[ -z $connectorWorkload ]]; then
        msg "Connector is not a Statefulset workload type."
        backupDataRequired=false
        proceedRecreate=false
        return;
    fi

    volumeName=$(oc get statefulset --namespace $NS $connectorWorkload -o jsonpath='{.spec.volumeClaimTemplates[].metadata.name}')
    volumeMountPath=$(oc get statefulset --namespace $NS $connectorWorkload -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="'$volumeName'")].mountPath }')
    dataFilePath=$volumeMountPath

    if [[ -z $dataFilePath ]]; then
        backupDataRequired=false
        proceedRecreate=true;
    fi      

    # Check if there's files to backup
    fileCount=$(oc exec --namespace $NS $connectorPod -- /bin/bash -c "find $volumeMountPath -type f | wc -l")
    if [ $fileCount -eq 0 ]; then
        echo "No files found in PVC to extract."
        backupDataRequired=false
    fi

    if [[ $proceedRecreate != "true" ]]; then
        msg "Connector looks OK."
        return;
    fi

    # Disable dataflow
    toggleDataFlow "$connconfig" "off"

    if [[ $backupDataRequired == "true" ]]; then

        targetDir=/tmp/$connconfig/$dataFilePath
        rm -rf $targetDir
        mkdir -p $targetDir

        CMD="oc cp --retries=3 --namespace $NS $connectorPod:$dataFilePath $targetDir/"
        info "Extracting data $dataFilePath file from pod: $connectorPod"
        printAndExecute "$CMD"

        msg "Files extracted"
        ls -R $targetDir

    fi
    
    connectorWorkload=$(oc get statefulset --namespace $NS --no-headers -l connectors.aiops.ibm.com/git-app-name=$gitappName -o jsonpath='{.items[*].metadata.name}')
    info "Scaling down connector workload: $connectorWorkload and delete PVC"
    CMD="oc scale --namespace $NS statefulset/$connectorWorkload --replicas 0 && oc delete pvc/$connectorPvc --namespace $NS --timeout=300s"
    printAndExecute "$CMD"

    info "Watching rollout ..."
    CMD="oc rollout status statefulset/$connectorWorkload --namespace $NS --timeout=300s"
    printAndExecute "$CMD"

    info "Deleting Statefulset: $connectorWorkload"
    CMD="oc delete statefulset/$connectorWorkload --namespace $NS --timeout=60s"
    printAndExecute "$CMD"

    local cycle=1
    local maxRetry=$((6 * 5)) # 5 minutes
    while [[ ! $(oc get statefulset --namespace $NS --no-headers -l connectors.aiops.ibm.com/git-app-name=$gitappName) ]]; do
        msg "Waiting for Statefulset to be created."
        sleep 10
        cycle=$(( $cycle + 1 ))
        if [ $cycle -gt $maxRetry ]; then
            errorAndExit "Timed out waiting for Statefulset to be created."
        fi
    done
}

function insertConnectorData(){

    if [[ $proceedRecreate != "true" ]]; then
        # No action required.
        return;
    fi
    connectorWorkload=$(oc get statefulset --namespace $NS --no-headers -l connectors.aiops.ibm.com/git-app-name=$gitappName -o jsonpath='{.items[*].metadata.name}')

    if [[ $backupDataRequired == "true" ]]; then
        title "Preparing to insert backup data."
        info "Checking for workload and PVC creation"

        local cycle=1
        local maxRetry=$((6 * 5)) # 5 minutes
        while [[ ! $(oc get statefulset --namespace $NS --no-headers -l connectors.aiops.ibm.com/git-app-name=$gitappName) ]]; do
            sleep 10
            cycle=$(( $cycle + 1 ))
            if [ $cycle -gt $maxRetry ]; then
                exit 1
            fi
        done

        connectorPvc=$(oc get pvc --namespace $NS --no-headers -l instance=connector-$connconfigUid -o jsonpath='{.items[*].metadata.name}')
        volumeName=$(oc get statefulset --namespace $NS $connectorWorkload -o jsonpath='{.spec.volumeClaimTemplates[].metadata.name}')
        volumeMountPath=$(oc get statefulset --namespace $NS $connectorWorkload -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[?(@.name=="'$volumeName'")].mountPath }')

        info "Found statefulset: $connectorWorkload, PVC: $connectorPvc"
        info "Making sure rollout is complete ..."
        CMD="oc rollout status --namespace $NS statefulset/$connectorWorkload --timeout=300s"
        printAndExecute "$CMD"

        local cycle=1
        local maxRetry=$((6 * 5)) # 5 minutes
        while [[ ! $(oc get pvc --namespace $NS --no-headers -l instance=connector-$connconfigUid) ]]; do
            sleep 10
            cycle=$(( $cycle + 1 ))
            if [ $cycle -gt $maxRetry ]; then
                error "Timeout waiting for PVC to be created. Exit."
                exit 1
            fi
        done

        connectorPod=$(oc get pod --no-headers --namespace $NS -l instance=connector-$connconfigUid -o jsonpath='{.items[*].metadata.name}')
        
        local cycle=1
        local maxRetry=$((6 * 5)) # 5 minutes
        while [[ $(oc get pod $connectorPod --namespace $NS --no-headers -o custom-columns=":status.phase") != "Running" ]]; do
            sleep 10
            cycle=$(( $cycle + 1 ))
            if [ $cycle -gt $maxRetry ]; then
                error "Timeout waiting for pod $connectorPod to run. Exit."
                exit 1
            fi
        done
        
        CMD="oc cp --retries=3 $targetDir $connectorPod:$volumeMountPath/.."
        info "Inserting data $targetDir directory into pod: $connectorPod"
        printAndExecute "$CMD"

        CMD="oc exec --namespace $NS $connectorPod -- /bin/bash -c \"find $volumeMountPath -type f\""
        printAndExecute "$CMD"

    fi
    
    info "Scaling down connector workload $connectorWorkload to restart pod."
    CMD="oc scale statefulset/$connectorWorkload --namespace $NS --replicas 0"
    printAndExecute "$CMD"

    info "Watching rollout ..."
    CMD="oc rollout status --namespace $NS statefulset/$connectorWorkload"
    printAndExecute "$CMD"

    CMD="oc scale statefulset/$connectorWorkload --namespace $NS --replicas 1"
    printAndExecute "$CMD"

    info "Watching rollout ..."
    CMD="oc rollout status --namespace $NS statefulset/$connectorWorkload"
    printAndExecute "$CMD"

    ## Enable dataflow
    toggleDataFlow "$connconfig" "on"

    connectorPvc=$(oc get pvc --namespace $NS --no-headers -l instance=connector-$connconfigUid -o jsonpath='{.items[*].metadata.name}')
    accessMode=$(getStorageAccessMode "$connectorPvc")

    msg "Connector PVC access mode: $accessMode"
}

function getConnectorInfo(){
    local connection=$1
    msg "Getting ConnectorConfiguration: $connection"
    CMD="oc get ConnectorConfiguration $connection --namespace $NS"
    printAndExecute "$CMD"

    connconfig=$(oc get connectorconfiguration --no-headers --namespace $NS --field-selector metadata.name=$connection -o jsonpath='{.items[*].metadata.name}')
    connconfigUid=$(oc get connectorconfiguration $connconfig --namespace $NS -o jsonpath='{.metadata.uid}')
    connconfigType=$(oc get connectorconfiguration $connconfig --namespace $NS -o jsonpath='{.spec.type}')
    gitappName=$(oc get gitapp --namespace $NS -l connectors.aiops.ibm.com/connection-id==$connconfigUid --no-headers -o jsonpath='{.items[*].metadata.name}')
    gitappStatus=$(oc get gitapp $gitappName --namespace $NS -o jsonpath='{.status.phase}')

    msg "ConnectorConfiguration id: $connconfigUid"
    msg "GitApp name: $gitappName"
}

function recreateStorage(){

    if [[ $ALL_CONNECTORS != "true" ]]; then
        title "Processing ConnectorConfiguration: $CONNECTION_NAME"
        getConnectorInfo "$CONNECTION_NAME"
        getDataFromStorage "$CONNECTION_NAME"
        insertConnectorData "$CONNECTION_NAME"
        success "Done processing ConnectorConfiguration: $CONNECTION_NAME"
    else
        count=1
        totalConnectors=$(oc get connectorconfiguration --no-headers -o jsonpath='{.items[*].metadata.name}' | wc -w | tr -d ' ')
        for connection in $(oc get connectorconfiguration --no-headers --namespace $NS -o jsonpath="{.items[*].metadata.name}"); do
            title "Processing ConnectorConfiguration ($count/$totalConnectors connectors): $connection"
            getConnectorInfo "$connection"
            getDataFromStorage "$connection"
            insertConnectorData "$connection"
            success "Done processing ConnectorConfiguration ($count/$totalConnectors connectors) : $connection"
            count=$((count + 1))
        done
    fi
}

function getStorageAccessMode(){
    local connectorPvc=$1
    pvcAccessMode=$(oc get pvc --namespace $NS $connectorPvc -o jsonpath='{.spec.accessModes[]}')
    echo $pvcAccessMode
}

function checkLoggedIn(){

    msg "Login check"
    if [ ! $(oc whoami) ]; then
        errorAndExit "You are not logged in to the cluster. Please make sure you are logged in."
    fi
}

function printAndExecute() {
    local cmd=$1
    msg "$cmd"
    eval "$cmd"
}

function msg() {
    printf '%b\n' "$1\n"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
}

function errorAndExit() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO] ${1}"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}


function main(){

    while [ "$#" -gt "0" ]
    do
        case "$1" in
        "-h"|"--help")
            usage
            exit 0
            ;;
        "-n"|"--namespace")
            NS=$2
            shift
            ;;
        "-c"|"--connection")
            CONNECTION_NAME=$2
            shift
            ;;
        "-a"|"--all")
            ALL_CONNECTORS="true"
            ;;
        *)
            warning "invalid option -- \`$1\`"
            usage
            exit 1
            ;;
        esac
        shift
    done

    title "Starting ..."
    if [[ -z $CONNECTION_NAME ]] && [[ $ALL_CONNECTORS == "false" ]]; then
        error "Script expects a ConnectorConfiguration resource name. Please specify a ConnectorConfiguration resource name."
        usage
        return
    fi

    if [[ -z ${NS:-} ]]; then
        error "Namespace is not specified. Please specify the AIOps namespace."
        usage
        return
    fi

    checkLoggedIn
    recreateStorage "$@"

    success "Complete ..."
}

main "$@"