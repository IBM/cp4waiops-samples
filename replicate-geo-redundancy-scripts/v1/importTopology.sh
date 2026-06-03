#!/usr/bin/env bash
# Fail on error
set -euo pipefail

# Set environment variables
set -a
source config.env
set +a

# ============================================
# Configuration
# ============================================
INPUT_FILE="${1:-topology-export.json}"

if [ ! -f "${INPUT_FILE}" ]; then
  echo "Error: Input file not found: ${INPUT_FILE}"
  echo "Usage: $0 [topology-export.json]"
  exit 1
fi

echo "Using input file: ${INPUT_FILE}"

# ============================================
# OpenShift Login: Backup Cluster
# ============================================
echo "Logging into OpenShift backup cluster..."
oc login "${BACKUP_CLUSTER_API_ENDPOINT}" \
  --token="${BACKUP_CLUSTER_TOKEN}" \
  --insecure-skip-tls-verify=true

# ============================================
# Get JWT Token
# ============================================
echo "Getting JWT token for backup cluster..."
CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
ACCESS_TOKEN=$(curl -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" ${CP_ROUTE}/idprovider/v1/auth/identitytoken | jq -r '.access_token')

export JWT_TOKEN=$(curl -k -X GET "${BACKUP_CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
-H "username: ${ADMIN_USER}" \
-H "iam-token: ${ACCESS_TOKEN}" | jq -r .accessToken)

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
  echo "Error: Failed to obtain JWT token"
  exit 1
fi

echo "JWT token obtained successfully"

# ============================================
# Import Topology Configuration
# ============================================
echo "Importing topology configuration from ${INPUT_FILE}..."

# Read the JSON file content
TOPOLOGY_DATA=$(cat "${INPUT_FILE}")

# Import topology configuration
HTTP_CODE=$(curl -k -X POST "${BACKUP_CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/restore" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${JWT_TOKEN}" \
  --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
  --data "${TOPOLOGY_DATA}" \
  --write-out "%{http_code}" \
  --silent \
  --output /dev/null)

# Check if import was successful
if [ "${HTTP_CODE}" -ge 200 ] && [ "${HTTP_CODE}" -lt 300 ]; then
  echo "Topology configuration imported successfully!"
  echo "HTTP Status: ${HTTP_CODE}"
else
  echo "Error: Failed to import topology configuration"
  echo "HTTP Status: ${HTTP_CODE}"
  
  # Try to get error details
  echo ""
  echo "Attempting to get error details..."
  curl -k -X POST "${BACKUP_CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/restore" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JWT_TOKEN}" \
    --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
    --data "${TOPOLOGY_DATA}" \
    --silent
  
  exit 1
fi

