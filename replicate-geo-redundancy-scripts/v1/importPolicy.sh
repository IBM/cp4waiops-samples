#!/usr/bin/env bash
# Fail on error
set -euo pipefail

# Set environment variables
set -a
source config.env
set +a

# Auto-detect platform and get route if BACKUP_CLUSTER_CPD_ENDPOINT is not set or empty
if [ -z "${BACKUP_CLUSTER_CPD_ENDPOINT}" ]; then
  echo "BACKUP_CLUSTER_CPD_ENDPOINT not set, attempting to auto-detect route..."
  
  # Check if we're on OpenShift (cpd route exists)
  if oc get route cpd -n "${BACKUP_CLUSTER_NAMESPACE}" &>/dev/null; then
    echo "Detected OpenShift Container Platform"
    ROUTE=$(oc get route cpd -n "${BACKUP_CLUSTER_NAMESPACE}" --no-headers | awk '{print $2}')
    BACKUP_CLUSTER_CPD_ENDPOINT="https://${ROUTE}"
    echo "Using route: ${BACKUP_CLUSTER_CPD_ENDPOINT}"
  # Check if we're on Linux (zen-ingress exists)
  elif oc get ingress zen-ingress -n "${BACKUP_CLUSTER_NAMESPACE}" &>/dev/null; then
    echo "Detected Linux installation"
    ROUTE=$(oc get ingress zen-ingress -n "${BACKUP_CLUSTER_NAMESPACE}" -o jsonpath='{.spec.rules[0].host}')
    BACKUP_CLUSTER_CPD_ENDPOINT="https://${ROUTE}"
    echo "Using route: ${BACKUP_CLUSTER_CPD_ENDPOINT}"
  else
    echo "Error: Could not detect platform or find route. Please set BACKUP_CLUSTER_CPD_ENDPOINT in config.env"
    exit 1
  fi
fi

# ============================================
# OpenShift Login: BACKUP
# ============================================
echo "Logging into OpenShift cluster..."
oc login "${BACKUP_CLUSTER_API_ENDPOINT}" \
  --token="${BACKUP_CLUSTER_TOKEN}" \
  --insecure-skip-tls-verify=true

# Need to do an OC login here. The token in config.env is used here
CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
ACCESS_TOKEN=$(curl -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" ${CP_ROUTE}/idprovider/v1/auth/identitytoken | jq -r '.access_token')

export JWT_TOKEN=$(curl -k -X GET "${BACKUP_CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
-H "username: ${ADMIN_USER}" \
-H "iam-token: ${ACCESS_TOKEN}" | jq -r .accessToken)

# Export policies
../../replicate-policies-scripts/v1/import_policies.py \
  --archive prod-policies.tar.gz \
  --target-url "$BACKUP_CLUSTER_CPD_ENDPOINT" \
  --target-token "$JWT_TOKEN" \
  --timeout 180


