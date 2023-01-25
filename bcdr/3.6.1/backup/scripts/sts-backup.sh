#!/bin/bash

# Global variables
EQUAL_TO="="
SEPARATOR="-"

CreateBackupPods() {
    # Input
    stsName=$1
    stsClaimName=$2
    stsReplicas=$3
    namespace=$4
    filePath=$5

    # Iterating over replicas
    index=0
    while [ $index -lt $stsReplicas ]; do
        # Computing Claim Name
        claimName=$stsClaimName
        claimName+=$SEPARATOR
        claimName+=$stsName
        claimName+=$SEPARATOR
        claimName+=$index

        # Computing Pod Name
        podName="backup"
        podName+=$SEPARATOR
        podName+=$claimName

        # Computing file name
        cp $filePath /tmp/$podName.yaml

        # Updating the pod name and claim in the pod definition
        sed -i 's/BACKUP_POD_NAME/'$(echo $podName)'/' /tmp/$podName.yaml
        sed -i 's/BACKUP_CLAIM_NAME/'$(echo $claimName)'/' /tmp/$podName.yaml
        sed -i 's/BACKUP_NAMESPACE/'$(echo $namespace)'/' /tmp/$podName.yaml

        # Creating the backup pods
        oc apply -f /tmp/$podName.yaml

        # Deleting pod definition YAML
        rm /tmp/$podName.yaml

        # Incrementing index
        index=$((index + 1))
    done
}
