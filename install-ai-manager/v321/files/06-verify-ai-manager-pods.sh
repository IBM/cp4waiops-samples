#!/usr/bin/env bash

function verify_ai_manager_pods () {

echo "-----------------------------------"
echo " 6. Verify Pods Count in WAIOps Namespace ($NAMESPACE)"
echo "-----------------------------------"

GLOBAL_POD_VERIFY_STATUS=false

POD_COUNT=0
MIN_POD_COUNT=110
MAX_WAIT_MINUTES=120
LOOP_COUNT=0

while [[ $POD_COUNT -lt $MIN_POD_COUNT ]] && [[ $LOOP_COUNT -lt $MAX_WAIT_MINUTES ]]; do
  POD_COUNT=$(oc get pods -n $NAMESPACE | wc -l ) 
  echo "WAIOps Pod Count in $LOOP_COUNT minutes : $POD_COUNT"
  LOOP_COUNT=$((LOOP_COUNT + 1))
  sleep 60
done

if [[ $POD_COUNT -gt $MIN_POD_COUNT ]]; then
  echo "WAIOps Namespace Pods counts are OK and it is more than $MIN_POD_COUNT"; 
  GLOBAL_POD_VERIFY_STATUS=true
else
  echo "Timed out waiting for PODs in ${NAMESPACE}"
  echo "Only $POD_COUNT pods are created in WAIOps namespace. It should be more than  $MIN_POD_COUNT"; 
  GLOBAL_POD_VERIFY_STATUS=false
fi
}