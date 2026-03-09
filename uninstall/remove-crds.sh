#!/bin/bash
# © Copyright IBM Corp. 2020, 2026
# SPDX-License-Identifier: Apache2.0
# This script removes the CRDs deployed by CP4AIOps.

CP4AIOPS_CRDS=("aimanagermainprods.ai-manager.watson-aiops.ibm.com" 
                "aimanagers.ai-manager.watson-aiops.ibm.com"
                "aimodeluis.consoleui.aiops.ibm.com"
                "aiopskafkatopics.connectors.aiops.ibm.com"
                "algorithms.ai-manager.watson-aiops.ibm.com"
                "baseuis.consoleui.aiops.ibm.com"
                "connectoruis.consoleui.aiops.ibm.com"
                "installations.orchestrator.aiops.ibm.com"
                "aiopsanalyticsorchestrators.ai.ir.aiops.ibm.com"
                "aiopsedges.connectors.aiops.ibm.com"
                "aiopsuis.consoleui.aiops.ibm.com"
                "automationactions.connectors.aiops.ibm.com"
                "bundlemanifests.connectors.aiops.ibm.com"
                "connectorcomponents.connectors.aiops.ibm.com"
                "connectorconfigurations.connectors.aiops.ibm.com"
                "connectorschemas.connectors.aiops.ibm.com"
                "gitapps.connectors.aiops.ibm.com"
                "insightsuis.consoleui.aiops.ibm.com"
                "issueresolutioncores.core.ir.aiops.ibm.com"
                "lifecycleservices.lifecycle.ir.aiops.ibm.com"
                "lifecycletriggers.lifecycle.ir.aiops.ibm.com"
                "flinkdeployments.flink.ibm.com"
                "flinksessionjobs.flink.ibm.com"
                "microedgeconfigurations.connectors.aiops.ibm.com"
                "clusters.opensearch.cloudpackopen.ibm.com"
                "nodepools.opensearch.cloudpackopen.ibm.com"
                "applications.tunnel.management.ibm.com"
                "tunnels.sretooling.management.ibm.com"
                "aiopsuiextensions.consoleui.aiops.ibm.com"
                )

checkForLeftOverCustomResources() {
   # Load the all arguments of checkForLeftOverCustomResources
   local CRDS=("$@")
   # Get the last argument of the function
   local last_index=$((${#CRDS[@]}-1))
   local CUSTOM_RESOURCE_TYPE="${CRDS[$last_index]}"
   # Remove the last argument from the array. This is necessary because $CRDS is an array of all arguments
   unset CRDS[$last_index]

   echo "Checking for $CUSTOM_RESOURCE_TYPE custom resources"

   # Poll for each CR for each CRD
   RESOURCE_FLAG="false"
   for CR in ${CRDS[@]}; do
       echo $CR
       check="$(oc get $CR -A)"
       if [[ -n "${check}" ]]; then
           RESOURCE_FLAG="true"
           oc get $CR -A --ignore-not-found
           echo
       else
           echo "None Found"
           echo
       fi
   done
   echo

   # If resources are found, exit with error
   if [[ "${RESOURCE_FLAG}" == "true" ]]; then
       echo "Some $CUSTOM_RESOURCE_TYPE CustomResources remain."
       exit 1
   fi

   echo "CRDs from $CUSTOM_RESOURCE_TYPE are safe to be deleted"
}


main() {
    checkForLeftOverCustomResources "${CP4AIOPS_CRDS[@]}" "CP4AIOps"

    for CRD in ${CP4AIOPS_CRDS[@]}; do
        echo "Deleting CRD $CRD.."
        oc delete crd $CRD --ignore-not-found
    done
    return 0
}

main
