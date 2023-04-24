#!/bin/bash

#
# Copyright 2023 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Parameter Constants
LOGGING_VERBOSITY=6;
KUBECTL_CMD="oc";
MAX_ATTEMPTS_FOR_SERVICE_ROLLOUT=100;
MANAGED_BY_REFERENCE="aiops-analytics-operator"; CR_REFERENCE="aiopsanalyticsorchestrator";

# Logging Constants
CRITICAL_LOG_LEVEL=1; ERROR_LOG_LEVEL=2; WARN_LOG_LEVEL=3; OP_SUCC_LEVEL=4;
INFO_LOG_LEVEL=5; DEBUG_LOG_LEVEL=6; STDOUT_RED='\033[0;31m'; STDOUT_GREEN='\033[0;32m';
STDOUT_YELLOW='\033[0;33m'; STDOUT_PURPLE='\033[0;35m';
STDOUT_RESET_CODE='\033[0m';

# Global variables
TRAPPED_STATUS_EXIT=0
ROLLOUTS_SUCCEEDED=""
ROLLOUTS_FAILED=""

# Logging Functions
function logcrit    () { LOG_LEVEL=$CRITICAL_LOG_LEVEL fmtlog "${STDOUT_RED}FATAL   - $@${STDOUT_RESET_CODE}" ;}
function logerr     () { LOG_LEVEL=$ERROR_LOG_LEVEL    fmtlog "${STDOUT_RED}ERROR   - $@${STDOUT_RESET_CODE}" ;}
function logdebug   () { LOG_LEVEL=$DEBUG_LOG_LEVEL    fmtlog "${STDOUT_PURPLE}DEBUG   - $@${STDOUT_RESET_CODE}" ;}
function loginfo    () { LOG_LEVEL=$INFO_LOG_LEVEL     fmtlog "INFO    - $@" ;}
function logwarn    () { LOG_LEVEL=$WARN_LOG_LEVEL     fmtlog "${STDOUT_YELLOW}WARNING - $@${STDOUT_RESET_CODE}" ;}
function logok      () { LOG_LEVEL=$OP_SUCC_LEVEL      fmtlog "${STDOUT_GREEN}SUCCESS - $@${STDOUT_RESET_CODE}" ;}
function fmtlog     () {
  if [ $LOGGING_VERBOSITY -ge $LOG_LEVEL ]; then
    datestring=`date +"%Y-%m-%d %H:%M:%S"`
    echo "$datestring - $@"
  fi
}

# Test Functions
# test_for_client is a function to check that the client executable exists on the path.
# arguments: $1 client command
function test_for_client() {
  loginfo "Testing that user Openshift client exists in path"
  which $1 &> /dev/null
  if [ $? -eq 0 ]; then
    logok "k8s Client exists in user path"
  else
    logcrit "The selected k8s client is not available"
    exit 1
  fi
}

# test_client_logged_in is a function to validate authorisation with an oc cluster.
# arguments: $1 client command
function test_client_logged_in() {
  loginfo "Testing for authentication against Openshift"
  $1 whoami &> /dev/null
  if [ $? -eq 0 ]; then
    logok "Authenticated against target oc cluster"
  else
    logcrit "You must be authenticated against the target \
    cluster with a CLI session in order to use this script"
    exit 1
  fi
}

# test_can_find_orchestrators_in_namespace is a function to search for CR instances in the namespace provided.
# arguments: $1 client command, $2 namespace
function test_can_find_orchestrators_in_namespace() {
  loginfo "Validating existance of orchestrators in the target namespace"
  COUNT=$($1 get $CR_REFERENCE -n $2 | wc -l)
  if [ "$COUNT" -eq "2" ]; then
    logok "Found $CR_REFERENCE within target namespace $2"
  else
    logwarn "Could not find expected number of instances of the CR $CR_REFERENCE in namespace $2"
    logcrit "Ensure there is exactly one instance of $CR_REFERENCE in namespace $2 to use this script"
    exit 1
  fi
}

# test_for_awk is a no arg dependency check function for awk
function test_for_awk_wc() {
  loginfo "Testing that user has awk installed in path"
  which awk &> /dev/null
  if [ $? -eq 0 ]; then
    logok "awk exists in user path"
  else
    logcrit "awk is required to use this script"
    exit 1
  fi

  loginfo "Testing that user has wc installed in path"
  which wc &> /dev/null
  if [ $? -eq 0 ]; then
    logok "wc exists in user path"
  else
    logcrit "wc is required to use this script"
    exit 1
  fi
}

# rotate_deployments_for_dependency is a function that will perform rollout restarts for
# a given array of deployments. arguments: @ - the array of deployments.
function rotate_deployments_for_dependency() {
  arr=("$@")
  for i in "${arr[@]}";
    do
      loginfo "Executing rollout restarts for deployment $i"
      $KUBECTL_CMD rollout restart $i
      ATTEMPTS=0
      
      ROLLOUT_STATUS_CMD="$KUBECTL_CMD rollout status $i"
      until $ROLLOUT_STATUS_CMD || [ $ATTEMPTS -eq $MAX_ATTEMPTS_FOR_SERVICE_ROLLOUT ]; do
        $ROLLOUT_STATUS_CMD
        ATTEMPTS=$((attempts + 1))
        loginfo \
        "failed attempt $ATTEMPTS executed of $MAX_ATTEMPTS_FOR_SERVICE_ROLLOUT,\
          awaiting rollout status progress"
        sleep 10
      done

      if [ $ATTEMPTS -ge $MAX_ATTEMPTS_FOR_SERVICE_ROLLOUT ]; then
        logerr "deployment $i did not healthy replicas in a reasonable timeframe"
        TRAPPED_STATUS_EXIT=1
        ROLLOUTS_FAILED="$ROLLOUTS_FAILED \n o- $i"
      else
        logok "successfully updated $i"
        ROLLOUTS_SUCCEEDED="$ROLLOUTS_SUCCEEDED \n o- $i"
      fi
    done
}

# clear_crt_cache_for_dependency is a function that will attempt to clear files in the global `$CERT_DIR`
# directory where the files match the pattern "$CERT_CACHE_PATTERN". This function assumes the STS members
# are numerically named according to the count of replicas. eg. abc-0, abc-1 for a count of 2.
function clear_crt_cache_for_dependency() {
  arr=("$@")
  for i in "${arr[@]}";
    do
      loginfo "Fetching replicas count for statefulset $i"
      REPLICA_COUNT_FOR_STS=$($KUBECTL_CMD get $i --no-headers=true -o custom-columns=":spec.replicas")
      echo "Found $REPLICA_COUNT_FOR_STS replicas for statefulset $i"
      REPLICA_COUNT_TO_ITTER_TO_FOR_STS=$((REPLICA_COUNT_FOR_STS - 1))
      STS_POD_TPL="$(echo $i |  awk -F'/' '{print $2}')"
      for replicaindex in $(seq 0 $REPLICA_COUNT_TO_ITTER_TO_FOR_STS); do
       echo "attempting to clear cert cache for replica $i-$z";
       $KUBECTL_CMD exec -ti $STS_POD_TPL-$replicaindex -- rm -rf /tmp/*-cert-sum \
          || echo "No work to do";
      done
    done
}

# Debug Information
logdebug "executing with oc client cmd: $KUBECTL_CMD"
USER_RUNNING_SCRIPT=$($KUBECTL_CMD whoami)
logdebug "executing script as $USER_RUNNING_SCRIPT"
CURRENT_NAMESPACE=$($KUBECTL_CMD config view --minify -o jsonpath='{..namespace}')
logdebug "executing against target namespace $CURRENT_NAMESPACE"

# Execute trivial tests to ensure all pre-reqs are satisfied
test_for_client $KUBECTL_CMD
test_client_logged_in $KUBECTL_CMD
test_can_find_orchestrators_in_namespace $KUBECTL_CMD $CURRENT_NAMESPACE
test_for_awk_wc

# Begin Main Execution

# Resolve the single orchestrator instance to determine annotations to select deployments via
# Use awk over grep/sed for higher compatibility against target systems.
loginfo "Attempting to resolve the target orchestrator instance"
ORCHESTRATOR_CR_INSTANCE=$(
  $KUBECTL_CMD get aiopsanalyticsorchestrator \
    -n $CURRENT_NAMESPACE --no-headers=true -o custom-columns=":metadata.name"
)

if [ "$(echo $ORCHESTRATOR_CR_INSTANCE | wc -l)" -eq 1 ] && 
   [ $(echo $ORCHESTRATOR_CR_INSTANCE | awk -F '//' '{ n = gsub(/ /, "", $1); print n }') -eq 0 ]; then
  logok "Obtained the orchestrator instance without errors: $ORCHESTRATOR_CR_INSTANCE"
else
  logwarn "Orchestrators should have only a single instance per namespace within the Cloud pak for AIOps."
  logwarn "Could not resolve the orchestrator instance. Either many exist, or none exist."
  logcrit "Contact IBM Support providing the logs of this script within the case."
  exit 1
fi

# Fetch the deployments based on the following labels: app.kubernetes.io/instance + app.kubernetes.io/managed-by
loginfo "Resolving deployments Using orchestrator instance $ORCHESTRATOR_CR_INSTANCE"
DEPLOYMENTS=()
while read -r line; do
   DEPLOYMENTS+=("$line")
done <<< "$($KUBECTL_CMD get deploy \
  --selector=app.kubernetes.io/managed-by=$MANAGED_BY_REFERENCE,app.kubernetes.io/instance=$ORCHESTRATOR_CR_INSTANCE \
  --no-headers=true -o name)"

DEPLOY_COUNT=$(echo "${DEPLOYMENTS[@]}" | awk '{print gsub("[ \t]",""); exit}')
if [ $DEPLOY_COUNT -ge 0 ]; then
  logok "Resolved deployments for orchestrator instance $ORCHESTRATOR_CR_INSTANCE without errors"
else
  logcrit "Could not find the expected number of deployments for the corresponding orchestrator instance"
  exit 1
fi

# Rotate the deployments over, to cycle certificates and secrets
logdebug "Detected deployments ${DEPLOYMENTS[@]}"
loginfo "Starting service rotation for $ORCHESTRATOR_CR_INSTANCE"
rotate_deployments_for_dependency "${DEPLOYMENTS[@]}"

# Finalise by checking if this is version 3.7, 3.7.0 or 3.7.1, where spark STS does not gracefully handle rotation
# Post 3.7.1 spark ought to handle certificate rotation automatically with grace.
RECONCILED_VERSION=$(
  $KUBECTL_CMD get aiopsanalyticsorchestrator $ORCHESTRATOR_CR_INSTANCE \
    --no-headers=true -o custom-columns=":status.versions.reconciled"
)
if [[ "$RECONCILED_VERSION" == "3.7.0" ]] || [[ "$RECONCILED_VERSION" == "3.7" ]] || [[ "$RECONCILED_VERSION" == "3.7.1" ]]; then
  # Attempt to find the spark STS. If upgrade could or was not complete,
  # it will be a deployment and handled via the rollout of deployments executed prior.
  loginfo "detected version 3.7.0/3.7.1, attempting to rollout Spark STS"
  STS=()
  while read -r line; do
    STS+=("$line")
  done <<< "$($KUBECTL_CMD get statefulset \
    --selector=app.kubernetes.io/managed-by=$MANAGED_BY_REFERENCE,app.kubernetes.io/instance=$ORCHESTRATOR_CR_INSTANCE \
    --no-headers=true -o name)"
  STS_COUNT==$(echo "${STS[@]}" | awk '{print gsub("[ \t]",""); exit}')
  if [ $DEPLOY_COUNT -ge 0 ]; then
    logdebug "Detected statefulsets ${STS[@]}"
    # Prior to rolling out the updates, lets clear the cert cache that is persistent in 3.7.0/3.7.1
    clear_crt_cache_for_dependency "${STS[@]}"
    rotate_deployments_for_dependency "${STS[@]}"
  else
    logdebug "Spark is assumed to still be in the deploy state from version 3.6 - no work to do"
  fi
fi

# Finalise and show status...
if [ $TRAPPED_STATUS_EXIT -eq 0 ]; then
  loginfo "Rollouts succeeded for:"
  echo $ROLLOUTS_SUCCEEDED
else
  loginfo "Rollouts failed for:"
  echo $ROLLOUTS_FAILED
fi

logdebug "preparing to exit with status $TRAPPED_STATUS_EXIT"
exit $TRAPPED_STATUS_EXIT
