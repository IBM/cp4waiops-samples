#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

CURRENT=$(pwd)
source $CURRENT/utils.sh

# Defining variables
basedir=$(dirname "$0")
details=$(cat /workdir/resource-label-details.json)
length=$(echo $details | jq '. | length')
index=0
resourceList=""
V_FALSE=FALSE

# Function for retriving the list of the resources by using partial resource name
getResourceList() {
    resourceType=$1
    resourceName=$2
    namespace=$3
    {
        # TRY
        if [[ "$resourceType" == 'pod' ]] || [[ "$resourceType" == 'pvc' ]]; then
            resourceList=$(oc get $resourceType -n $namespace | grep $resourceName | cut -d " " -f1)
        else
            resourceList=$resourceName
        fi
    } || {
        # CATCH
        echo "[WARNING] $(date) Error occured, Hence retrying once"
        if [[ "$resourceType" == 'pod' ]] || [[ "$resourceType" == 'pvc' ]]; then
            resourceList=$(oc get $resourceType -n $namespace | grep $resourceName | cut -d " " -f1)
        else
            resourceList=$resourceName
        fi
    }
    echo "[INFO] $(date) resourceList: $resourceList"
}

# Function to add label to the resources
addLabelToResources() {
    # Iterating over JSON
    while [ $index -lt $length ]; do
        # Computing resourceType, resourceName, labels & namespace
        resourceType=$(echo $details | jq -r --arg index $index '.[$index | tonumber].resourceType')
        resourceName=$(echo $details | jq -r --arg index $index '.[$index | tonumber].resourceName')
        labels=$(echo $details | jq -r --arg index $index '.[$index | tonumber].labels' | jq -r .[])
        namespace=$(echo $details | jq -r --arg index $index '.[$index | tonumber].namespace')

        # Check if namespace is enabled or not
        isNamespaceEnabled=$(IsNamespaceEnabled $namespace)
        if [ "$isNamespaceEnabled" = "$V_FALSE" ]; then
            # Incrementing Index
            index=$((index + 1))

            echo "[WARNING] $(date) Namespace [$namespace] is not enabled, hence skipping adding label to a $resourceType $resourceName"
            continue
        else
            echo "[INFO] $(date) Namespace [$namespace] is enabled, hence proceeding further for adding label to a $resourceType $resourceName"
        fi

        echo "[INFO] $(date) Looping over index: $index"
        echo "[INFO] $(date) ResourceType: $resourceType, ResourceName: $resourceName, Labels: $labels, Namespace: $namespace"

        if [[ "$resourceName" == '*' ]]; then
            command="oc label $resourceType -n $namespace --all $labels --overwrite=true"
            echo $command

            # Execute command
            {
                # TRY
                $(echo $command)
            } || {
                # CATCH
                echo "Error occured, Hence retrying once"
                $(echo $command)
            }
        else
            # Retriving the list of the resources that's need to be labeled
            getResourceList $resourceType $resourceName $namespace

            for resource in $resourceList; do
                # Creating label add command based on cluster wide or namespace specifc resource
                if [[ "$namespace" == '' ]]; then
                    echo "[INFO] $(date) Inside cluster wide resources block"
                    # Logging labels
                    echo "[INFO] $(date) Labels: $labels"
                    command="oc label $resourceType $resource $labels --overwrite=true"
                    echo $command
                else
                    echo "[INFO] $(date) Inside namespace specific resource block"
                    # Logging labels
                    echo "[INFO] $(date) Labels: $labels"
                    command="oc label $resourceType $resource -n $namespace $labels --overwrite=true"
                    echo $command
                fi

                # Execute command
                {
                    # TRY
                    $(echo $command)
                } || {
                    # CATCH
                    echo "[WARNING] $(date) Error occured, Hence retrying once"
                    $(echo $command)
                }

                # Sleep for some time
                sleep 1s
            done
        fi

        # Incrementing Index
        index=$((index + 1))
    done
}

# Add label to the resources
addLabelToResources
