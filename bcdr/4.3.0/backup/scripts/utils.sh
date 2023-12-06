#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

source $WORKDIR/common/common-utils.sh
velero_namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.veleroNamespace')

# Retrieving list of enabled namespaces
ENABLED_NAMESPACES=$(cat enabled-namespaces.json | jq -r '.[]')

# Retrieving list of enabled components
ENABLED_COMPONENTS=$(cat enabled-components.json | jq -r '.[]')

IsNamespaceEnabled() {
    namespaceToBeVerify=$1
    isNamespaceEnabled=FALSE

    for namespace in $ENABLED_NAMESPACES; do
        if [ "$namespace" = "$namespaceToBeVerify" ]; then
            isNamespaceEnabled=TRUE
            break
        fi
    done

    # Check for global or all namespaces.
    if [[ "$namespaceToBeVerify" == '' ]]; then
        isNamespaceEnabled=TRUE
    fi

    echo $isNamespaceEnabled
}

IsComponentEnabled() {
    componentToBeVerify=$1
    isComponentEnabled=FALSE

    for component in $ENABLED_COMPONENTS; do
        if [ "$component" = "$componentToBeVerify" ]; then
            isComponentEnabled=TRUE
            break
        fi
    done

    echo $isComponentEnabled
}


# This function is to check the backup status periodically till it's completion, it accepts one positional argument i.e backupName
waitTillBackupCompletion(){
   backupName=$1
   echo "[INFO] $(date) Waiting for backup $backupName to complete"
   wait "10"
   backupStatus=$(velero describe backup $backupName --details -n $velero_namespace | grep Phase | cut -d " " -f 3)
   echo "[INFO] $(date) Backup $backupName status is $backupStatus"
   
   while [ "$backupStatus" == "InProgress" ] || [ "$backupStatus" == "New" ]
   do
     echo "[INFO] $(date) Wating for 1 min"
     wait "60"
     backupStatus=$(velero describe backup $backupName --details -n $velero_namespace | grep Phase | cut -d " " -f 3)
     echo "[INFO] $(date) Velero Backup status is: $backupStatus"
   done
}
