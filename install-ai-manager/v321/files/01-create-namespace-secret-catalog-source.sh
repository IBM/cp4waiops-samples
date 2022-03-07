#!/usr/bin/env bash

function create_namespace_secret_catalog_source() {

echo "-----------------------------------"
echo "1. Installing IBM Cloud Pak for Watson AIOps AI Manager - pre-install started"
echo "-----------------------------------"

echo "1.1. Create namespace cp4waiops ..."
oc create namespace $NAMESPACE

sleep 3

echo "1.2. Create OperatorGroup ..."
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cp4waiops-operator-group
  namespace: $NAMESPACE
spec:
  targetNamespaces:
    - $NAMESPACE
EOF

sleep 3


echo "1.3. Create the entitlement key pull secret ..."
oc create secret docker-registry ibm-entitlement-key \
    --docker-username=cp\
    --docker-password=$ENTITLEMENT_KEY \
    --docker-server=cp.icr.io \
    --namespace=$NAMESPACE

sleep 3

echo "1.4. Create the topology service account with the entitlement key pull secret ..."
cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aiops-topology-service-account
  labels:
    managedByUser: 'true'
imagePullSecrets:
  - name: ibm-entitlement-key
EOF

sleep 3


echo "1.5. Ensure external traffic access to AI Manager"
if [ $(oc get ingresscontroller default -n openshift-ingress-operator -o jsonpath='{.status.endpointPublishingStrategy.type}') = "HostNetwork" ]; then oc patch namespace default --type=json -p '[{"op":"add","path":"/metadata/labels","value":{"network.openshift.io/policy-group":"ingress"}}]'; fi


echo "1.6. Create catalog source"
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
spec:
  displayName: ibm-operator-catalog
  publisher: IBM Content
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
EOF

sleep 5

echo "Process completed .... "

}