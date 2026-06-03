#!/usr/bin/env bash
# Fail on error
set -euo pipefail

# Set environment variables
set -a
source config.env
set +a

# ============================================
# OpenShift Login: Primary
# ============================================
echo "Logging into OpenShift cluster..."
oc login "${PRIMARY_CLUSTER_API_ENDPOINT}" \
  --namespace="${PRIMARY_CLUSTER_NAMESPACE}" \
  --token="${PRIMARY_CLUSTER_TOKEN}" \
  --insecure-skip-tls-verify=true

# Need to do an OC login here. The token in config.env is used here
CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
ACCESS_TOKEN=$(curl -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" ${CP_ROUTE}/idprovider/v1/auth/identitytoken | jq -r '.access_token')

export JWT_TOKEN=$(curl -k -X GET "${PRIMARY_CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
-H "username: ${ADMIN_USER}" \
-H "iam-token: ${ACCESS_TOKEN}" | jq -r .accessToken)

# Export policies
../../replicate-policies-scripts/v1/export_policies.py \
  --source-url "$PRIMARY_CLUSTER_CPD_ENDPOINT" \
  --source-token "$JWT_TOKEN" \
  --timeout 180 \
  --output prod-policies.tar.gz