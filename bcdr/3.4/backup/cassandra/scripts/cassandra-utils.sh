#!/bin/bash

namespace=$(cat ../../../common/aiops-config.json | jq -r '.aiopsNamespace')
#echo $namespace

kPodLoop() {
 __podPattern=$1
 __podCommand=$2
 __podList=$( oc get pods -n $namespace  --field-selector=status.phase=Running --no-headers=true --output=custom-columns=NAME:.metadata.name | grep ${__podPattern} )
 printf "Pods found: $(echo -n ${__podList})\n"
 for pod in ${__podList}; do
    printf "\n===== EXECUTING COMMAND in pod: %-42s =====\n" ${pod}
    oc exec ${pod} -n $namespace  -- bash -c "${__podCommand}"
    printf '_%.0s' {1..80}
    printf "\n"
 done;
}

