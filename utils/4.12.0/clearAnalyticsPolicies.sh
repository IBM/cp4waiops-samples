#!/bin/bash

#
# © Copyright IBM Corp. 2026
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

#
#   SYSTEM REQUIREMENTS
#  -----------------------------
#  1. The script requires the executing user to be authorised to view the cpadmin credentials (secrets)
#  2. The user must be logged into the AIOps namespace
#  3. The user must have the curl, kubectl, and jq CLI tools installed
#  4. The policies elastic system / policies user API must be functioning correctly in the target system.
#  5. The user requires the ability to exec into pods using the kubectl CLI.
#  6. The tool assumes bash 3.2 or higher. It aims to avoid the use of version, vendor or distribution specific capabilities.
#
#   TOOL OPERATION:
#  -----------------------------
# The tool operates in 4 key stages:
#  1. Use the cpadmin user to generate a zen JWT token used for authentication to the policy registry service.
#  2. Fetch policies by labels, stash them to file line by line (JSONL). The user should validate the policies file.
#  3. Truncate policies tables in Cassandra, removing data in such a away that we do not incur tombstones.
#  4. Reload the policies from the JSONL file into the system.
#
#   TOOL RISKS:
#  ------------------------------
#  1. In exceptional unforseen circumstances, for example where requirements were not met, policy data may be lost.
#     User policy data cannot be restored, nor can customisations to default policies. Analytics policies can be
#     regenerated from the latest data set. Due to this, users may prefer to initiate backup and restore processes
#     prior to executing this tool.

set -e

##### DECLARE FUNCTIONS AND SYS TRAP #####

# -- DEFINE TRAP
err() {
  local exit_code=$?
  
  # Kill any port forward processes
  if [ ! -z "$PORT_FORWARD_PID" ]; then
    echo "INFO: Cleaning up port forward (PID: $PORT_FORWARD_PID)"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    wait $PORT_FORWARD_PID 2>/dev/null || true
  fi
  
  # Kill any kubectl port-forward processes that might be lingering
  pkill -f "kubectl port-forward.*${INSTALL_NAMESPACE}" 2>/dev/null || true
  
  if [ $exit_code -ne 0 ]; then
    echo "WARNING: script failed with exit code $exit_code - please check logs to find failure step"
  fi
}

# -- SET FAILURE WARNING TRAP
trap err EXIT

# -- VALIDATION FUNCTIONS

validate_tooling() {
  echo "INFO: checking for kubectl"
  which kubectl
  echo "INFO: checking for curl"
  which curl
  echo "INFO: checking for jq"
  which jq
}

validate_kubectl_session() {
  echo "INFO: checking for kubectl session - upon failure, check the script prerequisites and repeat the procedure"
  kubectl auth can-i get pods --namespace=$INSTALL_NAMESPACE
  echo "INFO: kubectl session validated"
}

validate_cp4aiops_access() {
  if [ -z "$INSTALL_NAMESPACE" ]; then
    echo "ERROR: (config) - You must set the namespace parameter to use this script"
    exit 1
  fi
  echo "INFO: checking for access to the aiops in $INSTALL_NAMESPACE"
  kubectl config set-context --current --namespace=$INSTALL_NAMESPACE
}

validate_secret_access() {
  echo "INFO: validating access to platform-auth-idp-credentials secret"
  kubectl get secret platform-auth-idp-credentials -n $INSTALL_NAMESPACE > /dev/null
  echo "INFO: secret access validated"
}

# -- AUTHENTICATION FUNCTIONS

setup_zen_credentials() {
  echo "INFO: Setting up Zen credentials"
  LOGIN_USER="cpadmin"
  LOGIN_PASSWORD="$(kubectl get secret platform-auth-idp-credentials -n $INSTALL_NAMESPACE -o jsonpath='{.data.admin_password}' | base64 --decode)"
  echo "INFO: Credentials configured for user: ${LOGIN_USER}"
}

get_zen_token() {
  echo "INFO: Fetching the ZEN_API_HOST"
  ZEN_API_HOST=$(kubectl get route cpd -n $INSTALL_NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || kubectl get ingress cpd -n $INSTALL_NAMESPACE -o jsonpath='{.spec.rules[0].host}')
  echo "INFO: Resolved ZEN_API_HOST as value: $ZEN_API_HOST"
  
  echo "INFO: Fetching the IAM_IDP_HOST"
  IAM_IDP_HOST=$(kubectl get route platform-id-provider -n $INSTALL_NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || kubectl get ingress platform-id-provider -n $INSTALL_NAMESPACE -o jsonpath='{.spec.rules[0].host}')
  echo "INFO: Resolved the IAM_IDP_HOST as: $IAM_IDP_HOST"
  
  echo "INFO: Fetching ZEN_LOGIN_URL"
  ZEN_LOGIN_URL="https://${ZEN_API_HOST}/usermgmt/v1/usermgmt/getTimedToken"
  echo "INFO: Fetched the ZEN_LOGIN_URL as: $ZEN_LOGIN_URL"
  
  echo "INFO: Attempting authentication as user ${LOGIN_USER}"
  IAM_ACCESS_TOKEN=$(curl -k -X POST -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" https://${IAM_IDP_HOST}/idprovider/v1/auth/identitytoken -d "grant_type=password&username=${LOGIN_USER}&password=${LOGIN_PASSWORD}&scope=openid" 2> /dev/null | jq -r .access_token)
  echo "INFO: Retrieved IAM_ACCESS_TOKEN"
  
  echo "INFO: Validating authentication"
  ZEN_ACCESS_TOKEN=$(curl -k https://${ZEN_API_HOST}/v1/preauth/validateAuth -H 'username: cpadmin' -H "iam-token: ${IAM_ACCESS_TOKEN}" 2> /dev/null | jq -r .accessToken)
  echo "INFO: Retrieved ZEN_ACCESS_TOKEN"
  
  echo "INFO: Getting timed token"
  ZEN_LOGIN_RESPONSE=$(
    curl -k \
      -XPOST \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer ${ZEN_ACCESS_TOKEN}" \
      -H 'lifetime: 0' \
      -H 'cache-control: no-cache' \
      "${ZEN_LOGIN_URL}" \
      2> /dev/null
  )
  
  ZEN_LOGIN_MESSAGE=$(echo "${ZEN_LOGIN_RESPONSE}" | jq -r .message)
  
  if [ "${ZEN_LOGIN_MESSAGE}" != "success" ]; then
    echo "ERROR: Login failed: ${ZEN_LOGIN_MESSAGE}" 1>&2
    exit 2
  fi
  
  ZEN_TOKEN=$(echo "${ZEN_LOGIN_RESPONSE}" | jq -r .accessToken)
  echo "INFO: Successfully retrieved ZEN_TOKEN"
}

fetch_default_policies() {
  echo "INFO: Fetching policies with label 'isDefault=true'"
  
  # Determine the aiops prefix from the namespace or use default
  AIOPS_PREFIX="aiops"
  echo "DEBUG: Using AIOPS_PREFIX: ${AIOPS_PREFIX}"
  echo "DEBUG: Searching in namespace: ${INSTALL_NAMESPACE}"
  
  # List all pods for debugging
  echo "DEBUG: Available pods in namespace:"
  kubectl get pods -n $INSTALL_NAMESPACE --no-headers | awk '{print "  - " $1}'
  
  # Find the policy registry pod using the pattern
  POLICY_POD=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1)
  
  if [ -z "$POLICY_POD" ]; then
    echo "ERROR: Could not find policy registry pod matching pattern '${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc'" 1>&2
    echo "DEBUG: Tried pattern: ${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" 1>&2
    echo "DEBUG: Available pods listed above" 1>&2
    exit 3
  fi
  
  echo "INFO: Found policy pod: $POLICY_POD"
  
  # Check pod status
  POD_STATUS=$(kubectl get pod $POLICY_POD -n $INSTALL_NAMESPACE -o jsonpath='{.status.phase}')
  echo "DEBUG: Pod status: $POD_STATUS"
  
  if [ "$POD_STATUS" != "Running" ]; then
    echo "ERROR: Pod is not in Running state: $POD_STATUS" 1>&2
    exit 3
  fi
  
  # Set up port forwarding in background
  LOCAL_PORT=8080
  REMOTE_PORT=5601
  echo "INFO: Setting up port forward to pod ${POLICY_POD}:${REMOTE_PORT} on local port ${LOCAL_PORT}"
  kubectl port-forward -n $INSTALL_NAMESPACE pod/${POLICY_POD} ${LOCAL_PORT}:${REMOTE_PORT} > /tmp/port-forward.log 2>&1 &
  PORT_FORWARD_PID=$!
  
  echo "DEBUG: Port forward PID: $PORT_FORWARD_PID"
  
  # Wait for port forward to be ready
  echo "INFO: Waiting for port forward to be ready..."
  sleep 15
  
  # Check if port forward is still running
  if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
    echo "ERROR: Port forward process died" 1>&2
    echo "DEBUG: Port forward log:" 1>&2
    cat /tmp/port-forward.log 1>&2
    exit 3
  fi
  
  # Fetch policies with isDefault=true label
  # Query param: labels=[{"match":{"metadata.labels.ibm.com/is-default":"true"}}]
  # URL encoded: labels=%5B%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Fis-default%22%3A%22true%22%7D%7D%5D
  POLICY_API_URL="https://localhost:${LOCAL_PORT}/policyregistry.ibm-netcool-prod.aiops.io/v1alpha/user/policies?labels=%5B%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Fis-default%22%3A%22true%22%7D%7D%5D"
  TENANT_ID="cfd95b7e-3bc7-4006-a4a8-a73a79c71255"
  
  echo "INFO: Fetching policies from: $POLICY_API_URL"
  echo "DEBUG: Using ZEN_TOKEN (first 20 chars): ${ZEN_TOKEN:0:20}..."
  echo "DEBUG: Using x-tenant-id: $TENANT_ID"

  # Generate timestamp for consistent file naming
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  
  # Save full curl output (headers + body) to debug file
  DEBUG_FILE="curl_debug_output_${TIMESTAMP}.txt"
  echo "INFO: Saving full curl output (headers + body) to ${DEBUG_FILE}"
  
  curl -k -i -s \
    -X GET \
    -H 'accept: application/json' \
    -H "x-tenant-id: ${TENANT_ID}" \
    -H "x-subscription-id: ${TENANT_ID}" \
    -H "Authorization: Bearer ${ZEN_TOKEN}" \
    "${POLICY_API_URL}" > "$DEBUG_FILE" 2>&1
  
  echo "INFO: Full curl output saved to ${DEBUG_FILE}"
  
  # Get just the response body (without headers) for processing
  # Write directly to file to avoid shell variable issues
  echo "INFO: Fetching response body for processing"
  RAW_RESPONSE_FILE="raw_response_${TIMESTAMP}.json"
  curl -k -s \
    -X GET \
    -H 'accept: application/json' \
    -H "x-tenant-id: ${TENANT_ID}" \
    -H "x-subscription-id: ${TENANT_ID}" \
    -H "Authorization: Bearer ${ZEN_TOKEN}" \
    "${POLICY_API_URL}" > "$RAW_RESPONSE_FILE" 2>&1
  
  # Kill port forward
  echo "INFO: Cleaning up port forward"
  kill $PORT_FORWARD_PID 2>/dev/null || true
  wait $PORT_FORWARD_PID 2>/dev/null || true
  
  # Check if response file was created
  if [ ! -f "$RAW_RESPONSE_FILE" ] || [ ! -s "$RAW_RESPONSE_FILE" ]; then
    echo "ERROR: Empty or missing response from policy API" 1>&2
    exit 3
  fi
  
  FILE_SIZE=$(wc -c < "$RAW_RESPONSE_FILE")
  echo "DEBUG: Response body saved to ${RAW_RESPONSE_FILE}, size: ${FILE_SIZE} bytes"
  
  # The response body is an array of policies (not wrapped in an object)
  # Save policies to file (JSONL format - one policy per line)
  POLICIES_FILE="default_policies_${TIMESTAMP}.jsonl"
  echo "INFO: Saving policies to ${POLICIES_FILE}"
  
  # Convert policies array to JSONL (one policy per line)
  # Use --ascii-output to escape any problematic characters
  jq -c --ascii-output '.[]' "$RAW_RESPONSE_FILE" > "$POLICIES_FILE" 2>/dev/null || {
    echo "ERROR: Failed to parse JSON response" 1>&2
    echo "DEBUG: Check $RAW_RESPONSE_FILE for details" 1>&2
    exit 3
  }
  
  # Count the policies
  if [ -f "$POLICIES_FILE" ]; then
    POLICY_COUNT=$(wc -l < "$POLICIES_FILE")
    echo "INFO: Found ${POLICY_COUNT} policies with label 'isDefault=true'"
  else
    echo "ERROR: Failed to create policies file" 1>&2
    exit 3
  fi
  
  if [ ! -f "$POLICIES_FILE" ]; then
    echo "ERROR: Failed to create policies file" 1>&2
    exit 3
  fi
  
  FILE_SIZE=$(wc -l < "$POLICIES_FILE")
  echo "INFO: Policies saved to ${POLICIES_FILE} (${FILE_SIZE} lines)"
  echo "INFO: Please review the policies file before proceeding"
}

fetch_user_policies() {
  echo "INFO: Fetching policies with tag 'user'"
  
  # Determine the aiops prefix from the namespace or use default
  AIOPS_PREFIX="aiops"
  echo "DEBUG: Using AIOPS_PREFIX: ${AIOPS_PREFIX}"
  echo "DEBUG: Searching in namespace: ${INSTALL_NAMESPACE}"
  
  # Find the policy registry pod using the pattern
  POLICY_POD=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1)
  
  if [ -z "$POLICY_POD" ]; then
    echo "ERROR: Could not find policy registry pod matching pattern '${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc'" 1>&2
    exit 3
  fi
  
  echo "INFO: Found policy pod: $POLICY_POD"
  
  # Check pod status
  POD_STATUS=$(kubectl get pod $POLICY_POD -n $INSTALL_NAMESPACE -o jsonpath='{.status.phase}')
  echo "DEBUG: Pod status: $POD_STATUS"
  
  if [ "$POD_STATUS" != "Running" ]; then
    echo "ERROR: Pod is not in Running state: $POD_STATUS" 1>&2
    exit 3
  fi
  
  # Set up port forwarding in background
  LOCAL_PORT=8080
  REMOTE_PORT=5601
  echo "INFO: Setting up port forward to pod ${POLICY_POD}:${REMOTE_PORT} on local port ${LOCAL_PORT}"
  kubectl port-forward -n $INSTALL_NAMESPACE pod/${POLICY_POD} ${LOCAL_PORT}:${REMOTE_PORT} > /tmp/port-forward-user.log 2>&1 &
  PORT_FORWARD_PID=$!
  
  echo "DEBUG: Port forward PID: $PORT_FORWARD_PID"
  
  # Wait for port forward to be ready
  echo "INFO: Waiting for port forward to be ready..."
  sleep 15
  
  # Check if port forward is still running
  if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
    echo "ERROR: Port forward process died" 1>&2
    echo "DEBUG: Port forward log:" 1>&2
    cat /tmp/port-forward-user.log 1>&2
    exit 3
  fi
  
  # Fetch policies with labels: isDefault=false AND managed-by-analytics=false
  # Query param: labels=[{"match":{"metadata.labels.ibm.com/is-default":"false"}},{"match":{"metadata.labels.ibm.com/aiops/managed-by-analytics":"false"}}]
  # URL encoded: labels=%5B%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Fis-default%22%3A%22false%22%7D%7D%2C%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Faiops%2Fmanaged-by-analytics%22%3A%22false%22%7D%7D%5D
  POLICY_API_URL="https://localhost:${LOCAL_PORT}/policyregistry.ibm-netcool-prod.aiops.io/v1alpha/user/policies?labels=%5B%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Fis-default%22%3A%22false%22%7D%7D%2C%7B%22match%22%3A%7B%22metadata.labels.ibm.com%2Faiops%2Fmanaged-by-analytics%22%3A%22false%22%7D%7D%5D"
  TENANT_ID="cfd95b7e-3bc7-4006-a4a8-a73a79c71255"
  
  echo "INFO: Fetching policies from: $POLICY_API_URL"
  echo "DEBUG: Using ZEN_TOKEN (first 20 chars): ${ZEN_TOKEN:0:20}..."
  echo "DEBUG: Using x-tenant-id: $TENANT_ID"

  # Generate timestamp for consistent file naming
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  
  # Save full curl output (headers + body) to debug file
  DEBUG_FILE="curl_debug_output_user_${TIMESTAMP}.txt"
  echo "INFO: Saving full curl output (headers + body) to ${DEBUG_FILE}"
  
  curl -k -i -s \
    -X GET \
    -H 'accept: application/json' \
    -H "x-tenant-id: ${TENANT_ID}" \
    -H "x-subscription-id: ${TENANT_ID}" \
    -H "Authorization: Bearer ${ZEN_TOKEN}" \
    "${POLICY_API_URL}" > "$DEBUG_FILE" 2>&1
  
  echo "INFO: Full curl output saved to ${DEBUG_FILE}"
  
  # Get just the response body (without headers) for processing
  # Write directly to file to avoid shell variable issues
  echo "INFO: Fetching response body for processing"
  RAW_RESPONSE_FILE="raw_response_user_${TIMESTAMP}.json"
  curl -k -s \
    -X GET \
    -H 'accept: application/json' \
    -H "x-tenant-id: ${TENANT_ID}" \
    -H "x-subscription-id: ${TENANT_ID}" \
    -H "Authorization: Bearer ${ZEN_TOKEN}" \
    "${POLICY_API_URL}" > "$RAW_RESPONSE_FILE" 2>&1
  
  # Kill port forward
  echo "INFO: Cleaning up port forward"
  kill $PORT_FORWARD_PID 2>/dev/null || true
  wait $PORT_FORWARD_PID 2>/dev/null || true
  
  # Check if response file was created
  if [ ! -f "$RAW_RESPONSE_FILE" ] || [ ! -s "$RAW_RESPONSE_FILE" ]; then
    echo "ERROR: Empty or missing response from policy API" 1>&2
    exit 3
  fi
  
  FILE_SIZE=$(wc -c < "$RAW_RESPONSE_FILE")
  echo "DEBUG: Response body saved to ${RAW_RESPONSE_FILE}, size: ${FILE_SIZE} bytes"
  
  # The response body is an array of policies (not wrapped in an object)
  # Save policies to file (JSONL format - one policy per line)
  POLICIES_FILE="user_policies_${TIMESTAMP}.jsonl"
  echo "INFO: Saving user policies to ${POLICIES_FILE}"
  
  # Convert policies array to JSONL (one policy per line)
  # Use --ascii-output to escape any problematic characters
  jq -c --ascii-output '.[]' "$RAW_RESPONSE_FILE" > "$POLICIES_FILE" 2>/dev/null || {
    echo "ERROR: Failed to parse JSON response" 1>&2
    echo "DEBUG: Check $RAW_RESPONSE_FILE for details" 1>&2
    exit 3
  }
  
  # Count the policies
  if [ -f "$POLICIES_FILE" ]; then
    POLICY_COUNT=$(wc -l < "$POLICIES_FILE")
    echo "INFO: Found ${POLICY_COUNT} user policies"
  else
    echo "ERROR: Failed to create policies file" 1>&2
    exit 3
  fi
  
  if [ ! -f "$POLICIES_FILE" ]; then
    echo "ERROR: Failed to create policies file" 1>&2
    exit 3
  fi
  
  FILE_SIZE=$(wc -l < "$POLICIES_FILE")
  echo "INFO: User policies saved to ${POLICIES_FILE} (${FILE_SIZE} lines)"
  echo "INFO: Please review the policies file before proceeding"
}

reload_policies_from_jsonl() {
  local JSONL_FILE=$1
  
  if [ -z "$JSONL_FILE" ]; then
    echo "ERROR: JSONL file path is required" 1>&2
    exit 1
  fi
  
  if [ ! -f "$JSONL_FILE" ]; then
    echo "ERROR: JSONL file not found: $JSONL_FILE" 1>&2
    exit 1
  fi
  
  echo "INFO: Reloading policies from ${JSONL_FILE}"
  
  # Count total policies
  TOTAL_POLICIES=$(wc -l < "$JSONL_FILE")
  echo "INFO: Found ${TOTAL_POLICIES} policies to reload"
  
  # Set up port forwarding to policy pod
  AIOPS_PREFIX="aiops"
  POLICY_POD=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1)
  
  if [ -z "$POLICY_POD" ]; then
    echo "ERROR: Could not find policy registry pod" 1>&2
    exit 3
  fi
  
  echo "INFO: Found policy pod: $POLICY_POD"
  
  LOCAL_PORT=8080
  REMOTE_PORT=5601
  echo "INFO: Setting up port forward to pod ${POLICY_POD}:${REMOTE_PORT} on local port ${LOCAL_PORT}"
  kubectl port-forward -n $INSTALL_NAMESPACE pod/${POLICY_POD} ${LOCAL_PORT}:${REMOTE_PORT} > /tmp/port-forward-reload.log 2>&1 &
  PORT_FORWARD_PID=$!
  
  echo "INFO: Waiting for port forward to be ready..."
  sleep 15
  
  # Check if port forward is still running
  if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
    echo "ERROR: Port forward process died" 1>&2
    cat /tmp/port-forward-reload.log 1>&2
    exit 3
  fi
  
  # API endpoint for creating policies
  POLICY_API_URL="https://localhost:${LOCAL_PORT}/policyregistry.ibm-netcool-prod.aiops.io/v1alpha/user/policies"
  TENANT_ID="cfd95b7e-3bc7-4006-a4a8-a73a79c71255"
  
  # Post each policy line by line
  SUCCESS_COUNT=0
  FAIL_COUNT=0
  LINE_NUM=0
  
  while IFS= read -r policy_line; do
    LINE_NUM=$((LINE_NUM + 1))
    
    # Skip empty lines
    if [ -z "$policy_line" ]; then
      continue
    fi
    
    echo "INFO: Posting policy ${LINE_NUM}/${TOTAL_POLICIES}..."
    
    # Post the policy
    HTTP_CODE=$(curl -k -s -w "%{http_code}" -o /tmp/policy_post_response.json \
      -X POST \
      -H 'Content-Type: application/json' \
      -H 'accept: application/json' \
      -H "x-tenant-id: ${TENANT_ID}" \
      -H "x-subscription-id: ${TENANT_ID}" \
      -H "Authorization: Bearer ${ZEN_TOKEN}" \
      -d "$policy_line" \
      "${POLICY_API_URL}")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      echo "  Success (HTTP ${HTTP_CODE})"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "  Failed (HTTP ${HTTP_CODE})" 1>&2
      echo "  Response: $(cat /tmp/policy_post_response.json)" 1>&2
    fi
    
  done < "$JSONL_FILE"
  
  # Clean up port forward
  echo "INFO: Cleaning up port forward"
  kill $PORT_FORWARD_PID 2>/dev/null || true
  wait $PORT_FORWARD_PID 2>/dev/null || true
  
  echo ""
  echo "=========================================="
  echo "RELOAD SUMMARY:"
  echo "=========================================="
  echo "Total policies: ${TOTAL_POLICIES}"
  echo "Successfully posted: ${SUCCESS_COUNT}"
  echo "Failed: ${FAIL_COUNT}"
  echo "=========================================="
  
  if [ $FAIL_COUNT -gt 0 ]; then
    echo "WARNING: Some policies failed to reload" 1>&2
    return 1
  fi
  
  echo "INFO: All policies reloaded successfully"
}

reload_default_policies_to_system() {
  local JSONL_FILE=$1
  
  if [ -z "$JSONL_FILE" ]; then
    echo "ERROR: JSONL file path is required" 1>&2
    exit 1
  fi
  
  if [ ! -f "$JSONL_FILE" ]; then
    echo "ERROR: JSONL file not found: $JSONL_FILE" 1>&2
    exit 1
  fi
  
  echo "INFO: Reloading default policies to system API from ${JSONL_FILE}"
  
  # Count total policies
  TOTAL_POLICIES=$(wc -l < "$JSONL_FILE")
  echo "INFO: Found ${TOTAL_POLICIES} policies to reload"
  
  # Get basic auth credentials from secret
  RELEASE_NAME=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1 | sed 's/-ir-lifecycle-policy-registry-svc.*//')
  
  if [ -z "$RELEASE_NAME" ]; then
    echo "ERROR: Could not determine release name" 1>&2
    exit 3
  fi
  
  SECRET_NAME="${RELEASE_NAME}-ir-lifecycle-policy-registry-svc"
  echo "INFO: Using secret: ${SECRET_NAME}"
  
  # Get credentials from secret
  BASIC_AUTH_USER=$(kubectl get secret $SECRET_NAME -n $INSTALL_NAMESPACE -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode)
  BASIC_AUTH_PASS=$(kubectl get secret $SECRET_NAME -n $INSTALL_NAMESPACE -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode)
  
  if [ -z "$BASIC_AUTH_USER" ] || [ -z "$BASIC_AUTH_PASS" ]; then
    echo "ERROR: Could not retrieve credentials from secret ${SECRET_NAME}" 1>&2
    exit 3
  fi
  
  echo "INFO: Retrieved credentials for user: ${BASIC_AUTH_USER}"
  
  # Set up port forwarding to policy pod
  AIOPS_PREFIX="aiops"
  POLICY_POD=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1)
  
  if [ -z "$POLICY_POD" ]; then
    echo "ERROR: Could not find policy registry pod" 1>&2
    exit 3
  fi
  
  echo "INFO: Found policy pod: $POLICY_POD"
  
  LOCAL_PORT=8080
  REMOTE_PORT=5601
  echo "INFO: Setting up port forward to pod ${POLICY_POD}:${REMOTE_PORT} on local port ${LOCAL_PORT}"
  kubectl port-forward -n $INSTALL_NAMESPACE pod/${POLICY_POD} ${LOCAL_PORT}:${REMOTE_PORT} > /tmp/port-forward-reload-system.log 2>&1 &
  PORT_FORWARD_PID=$!
  
  echo "INFO: Waiting for port forward to be ready..."
  sleep 15
  
  # Check if port forward is still running
  if ! kill -0 $PORT_FORWARD_PID 2>/dev/null; then
    echo "ERROR: Port forward process died" 1>&2
    cat /tmp/port-forward-reload-system.log 1>&2
    exit 3
  fi
  
  # API endpoint for system policies
  TENANT_ID="cfd95b7e-3bc7-4006-a4a8-a73a79c71255"
  POLICY_API_URL="https://localhost:${LOCAL_PORT}/policyregistry.ibm-netcool-prod.aiops.io/v1alpha/system/${TENANT_ID}/policies?preservepolicyid=true"
  
  # Post each policy line by line
  SUCCESS_COUNT=0
  FAIL_COUNT=0
  LINE_NUM=0
  
  while IFS= read -r policy_line; do
    LINE_NUM=$((LINE_NUM + 1))
    
    # Skip empty lines
    if [ -z "$policy_line" ]; then
      continue
    fi
    
    echo "INFO: Posting policy ${LINE_NUM}/${TOTAL_POLICIES}"
    
    # Post the policy using basic auth
    HTTP_CODE=$(curl -k -s -w "%{http_code}" -o /tmp/policy_post_response.json \
      -X POST \
      -H 'Content-Type: application/json' \
      -H 'accept: application/json' \
      -u "${BASIC_AUTH_USER}:${BASIC_AUTH_PASS}" \
      -d "$policy_line" \
      "${POLICY_API_URL}")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
      SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      echo "  Success (HTTP ${HTTP_CODE})"
    else
      FAIL_COUNT=$((FAIL_COUNT + 1))
      echo "  Failed (HTTP ${HTTP_CODE})" 1>&2
      echo "  Response: $(cat /tmp/policy_post_response.json)" 1>&2
    fi
    
  done < "$JSONL_FILE"
  
  # Clean up port forward
  echo "INFO: Cleaning up port forward"
  kill $PORT_FORWARD_PID 2>/dev/null || true
  wait $PORT_FORWARD_PID 2>/dev/null || true
  
  echo ""
  echo "=========================================="
  echo "RELOAD SUMMARY (SYSTEM API):"
  echo "=========================================="
  echo "Total policies: ${TOTAL_POLICIES}"
  echo "Successfully posted: ${SUCCESS_COUNT}"
  echo "Failed: ${FAIL_COUNT}"
  echo "=========================================="
  
  if [ $FAIL_COUNT -gt 0 ]; then
    echo "WARNING: Some policies failed to reload" 1>&2
    return 1
  fi
  
  echo "INFO: All default policies reloaded successfully to system API"
}

run_policy_upgrade() {
  echo ""
  echo "=========================================="
  echo "RUNNING POLICY UPGRADE"
  echo "=========================================="
  echo ""
  
  echo "INFO: Waiting 30 seconds for truncation to complete..."
  sleep 30
  
  # Run upgrade command in policy registry pod
  echo "INFO: Running upgrade command in policy registry pod..."
  AIOPS_PREFIX="aiops"
  POLICY_POD=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "${AIOPS_PREFIX}-ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1)
  
  if [ -z "$POLICY_POD" ]; then
    echo "ERROR: Could not find policy registry pod" 1>&2
    exit 3
  fi
  
  echo "INFO: Executing upgrade in pod: ${POLICY_POD}"
  kubectl exec -n $INSTALL_NAMESPACE $POLICY_POD -- bash -c 'cd /app/lib/tools && /app/entrypoint.sh node upgrade --tenantid $API_AUTHSCHEME_NOIUSERS_TENANTID'
  
  echo "INFO: Upgrade command completed successfully"
}

truncate_cassandra_tables() {
  echo ""
  echo "=========================================="
  echo "TRUNCATING CASSANDRA TABLES"
  echo "=========================================="
  echo ""

  # Determine release name from policy pod
  RELEASE_NAME=$(kubectl get pods -n $INSTALL_NAMESPACE --no-headers | grep "ir-lifecycle-policy-registry-svc" | awk '{print $1}' | head -n 1 | awk -F'-ir-lifecycle-policy-registry-svc' '{print $1}')

  if [ -z "$RELEASE_NAME" ]; then
    echo "ERROR: Could not determine release name" 1>&2
    exit 3
  fi

  echo "INFO: Detected release name: ${RELEASE_NAME}"

  # Find Cassandra pod (use replica 0)
  CASSANDRA_POD="${RELEASE_NAME}-topology-cassandra-0"
  echo "INFO: Looking for Cassandra pod: ${CASSANDRA_POD}"

  # Verify pod exists and is running
  POD_STATUS=$(kubectl get pod $CASSANDRA_POD -n $INSTALL_NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)

  if [ -z "$POD_STATUS" ]; then
    echo "ERROR: Cassandra pod not found: ${CASSANDRA_POD}" 1>&2
    exit 3
  fi

  if [ "$POD_STATUS" != "Running" ]; then
    echo "ERROR: Cassandra pod is not in Running state: ${POD_STATUS}" 1>&2
    exit 3
  fi

  echo "INFO: Cassandra pod found and running: ${CASSANDRA_POD}"
  echo "INFO: Executing truncate script..."

  # Execute truncate script
  # Use single quotes to prevent outer shell expansion, and escape inner single quotes
  kubectl exec -n $INSTALL_NAMESPACE $CASSANDRA_POD -- bash -c 'cqlsh -u $(cat $CASSANDRA_AUTH_USERNAME_FILE) -p $(cat $CASSANDRA_AUTH_PASSWORD_FILE) -e "truncate aiops_policies.aiops_policies; truncate aiops_policies.eventid_to_policy; truncate aiops_policies.policies; truncate aiops_policies.aiops_nohotfields; truncate aiops_policies.policy_timeline; truncate aiops_policies.hotfield_to_policy;" --ssl'

  echo "INFO: Cassandra tables truncated successfully"
}

confirm_and_proceed() {
  echo ""
  echo "=========================================="
  echo "POLICY EXPORT COMPLETE"
  echo "=========================================="
  echo ""
  echo "Please review the exported policy files:"
  echo "  - default_policies_*.jsonl (default policies)"
  echo "  - user_policies_*.jsonl (user-defined policies)"
  echo ""
  echo "WARNING: The next step will truncate Cassandra tables and reload policies."
  echo "This operation cannot be undone."
  echo ""
  read -p "Do you want to proceed with truncation and reload? (yes/no): " CONFIRM

  if [ "$CONFIRM" != "yes" ]; then
    echo "INFO: Operation cancelled by user"
    exit 0
  fi
}

##### PARSE COMMAND LINE ARGUMENTS #####

# -- DEFAULT VALUES
INSTALL_NAMESPACE=""
RELOAD_ONLY=false

# -- PARSE OPTIONS
while getopts "n:r" opt; do
  case $opt in
    n)
      INSTALL_NAMESPACE="$OPTARG"
      ;;
    r)
      RELOAD_ONLY=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 -n <install_namespace> [-r]"
      echo "  -n: Install namespace (required)"
      echo "  -r: Reload-only mode (skip export and truncation)"
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# -- VALIDATE REQUIRED PARAMETERS
if [ -z "$INSTALL_NAMESPACE" ]; then
  echo "Error: Install namespace is required"
  echo "Usage: $0 -n <install_namespace> [-r]"
  echo "  -n: Install namespace (required)"
  echo "  -r: Reload-only mode (skip export and truncation)"
  exit 1
fi

echo "Using install namespace: $INSTALL_NAMESPACE"

if [ "$RELOAD_ONLY" = true ]; then
  echo "INFO: Running in RELOAD-ONLY mode"
  echo "INFO: Skipping export, truncation, and upgrade steps"
else
  echo "INFO: Running in FULL mode (export, truncate, upgrade, reload)"
fi

# -- RUN VALIDATION STEPS
validate_tooling
validate_kubectl_session
validate_cp4aiops_access
validate_secret_access

# -- SETUP AUTHENTICATION
setup_zen_credentials
get_zen_token

echo "ZEN_TOKEN: ${ZEN_TOKEN}"

if [ "$RELOAD_ONLY" = false ]; then
  # -- FETCH DEFAULT POLICIES
  fetch_default_policies

  # -- FETCH USER POLICIES
  fetch_user_policies

  # -- USER CONFIRMATION
  confirm_and_proceed

  # -- TRUNCATE CASSANDRA TABLES
  truncate_cassandra_tables

  # -- RUN POLICY UPGRADE
  run_policy_upgrade
fi

# -- RELOAD DEFAULT POLICIES VIA SYSTEM API
echo ""
echo "=========================================="
echo "RELOADING DEFAULT POLICIES"
echo "=========================================="
echo ""

# Find the most recent default policies JSONL file
LATEST_DEFAULT_JSONL=$(ls -t default_policies_*.jsonl 2>/dev/null | head -n 1)

if [ -z "$LATEST_DEFAULT_JSONL" ]; then
  echo "ERROR: No default policies JSONL file found" 1>&2
  exit 1
fi

echo "INFO: Reloading default policies via system API"
echo "INFO: Using file: $LATEST_DEFAULT_JSONL"
reload_default_policies_to_system "$LATEST_DEFAULT_JSONL"

# -- RELOAD USER POLICIES VIA USER API
echo ""
echo "=========================================="
echo "RELOADING USER POLICIES"
echo "=========================================="
echo ""

# Find the most recent user policies JSONL file
LATEST_USER_JSONL=$(ls -t user_policies_*.jsonl 2>/dev/null | head -n 1)

if [ -z "$LATEST_USER_JSONL" ]; then
  echo "INFO: No user policies found to reload"
else
  echo "INFO: Reloading user policies via user API"
  echo "INFO: Using file: $LATEST_USER_JSONL"
  reload_policies_from_jsonl "$LATEST_USER_JSONL"
fi

echo ""
echo "=========================================="
echo "POLICY RELOAD COMPLETE"
echo "=========================================="

exit 0
