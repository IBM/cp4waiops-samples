#!/usr/bin/env bash
# Fail on error
set -euo pipefail

# Set environment variables
set -a
source geo_config.env
set +a

# ============================================
# OpenShift Login: Primary
# ============================================
echo "Logging into OpenShift cluster..."
oc login "${PRIMARY_CLUSTER_API_ENDPOINT}" \
  --namespace="${PRIMARY_CLUSTER_NAMESPACE}" \
  --token="${PRIMARY_CLUSTER_TOKEN}" \
  --insecure-skip-tls-verify=true

# ============================================
# Get JWT Token
# ============================================
echo "Getting JWT token..."
CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
ACCESS_TOKEN=$(curl -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" ${CP_ROUTE}/idprovider/v1/auth/identitytoken | jq -r '.access_token')

export JWT_TOKEN=$(curl -k -X GET "${PRIMARY_CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
-H "username: ${ADMIN_USER}" \
-H "iam-token: ${ACCESS_TOKEN}" | jq -r .accessToken)

if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
  echo "Error: Failed to obtain JWT token"
  exit 1
fi

echo "JWT token obtained successfully"

# ============================================
# Export Topology Configuration
# ============================================
OUTPUT_FILE="topology-export.json"
OUTPUT_FILE_TMP="${OUTPUT_FILE}.tmp"
echo "Exporting topology configuration to ${OUTPUT_FILE}..."

curl -k -X GET "${PRIMARY_CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/backup" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${JWT_TOKEN}" \
  --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
  --output "${OUTPUT_FILE_TMP}" \
  --silent \
  --show-error

# Check if export was successful
if [ $? -eq 0 ] && [ -f "${OUTPUT_FILE_TMP}" ]; then
  # Prettify the JSON output
  echo "Formatting JSON..."
  if jq '.' "${OUTPUT_FILE_TMP}" > "${OUTPUT_FILE}" 2>/dev/null; then
    rm -f "${OUTPUT_FILE_TMP}"
    FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null)
    echo "Topology configuration exported successfully!"
    echo "Output file: ${OUTPUT_FILE}"
    echo "File size: ${FILE_SIZE} bytes"
  else
    # If jq fails, just use the original file
    echo "Warning: Could not prettify JSON, using raw format"
    mv "${OUTPUT_FILE_TMP}" "${OUTPUT_FILE}"
    FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null)
    echo "Topology configuration exported successfully!"
    echo "Output file: ${OUTPUT_FILE}"
    echo "File size: ${FILE_SIZE} bytes"
  fi
else
  echo "Error: Failed to export topology configuration"
  rm -f "${OUTPUT_FILE_TMP}"
  exit 1
fi