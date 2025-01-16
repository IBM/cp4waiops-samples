#!/bin/bash
#
# © Copyright IBM Corp. 2024
# SPDX-License-Identifier: Apache2.0
#
#This reference script can be used to install the OpenShift LokiStack for
# cluster logging as documented in:
#   https://docs.openshift.com/container-platform/4.15/observability/logging/cluster-logging-deploying.html#logging-loki-cli-install_cluster-logging-deploying
# and
#   https://docs.openshift.com/container-platform/4.15/observability/logging/log_storage/cluster-logging-loki.html
#
#The script can be used in a production environment, but is not a substitute
# for thorough planning or an understanding of the installation process and its
# consequences.
#
#Important:
# - Further customizations and modifications to this script are expected to
#   ensure that it aligns with your requirements.
# - LOKI requires object storage, so ensure that object storage is available
#   [ s3, azure, gcs, swift ]. Only local ODF S3 was attempted with this script.
#

#set -x

# LOKI Logging size and consequences
#   https://docs.openshift.com/container-platform/4.15/observability/logging/log_storage/installing-log-storage.html#loki-deployment-sizing_installing-log-storage
#
#  demo:        minimal cpu/memory, 80G disk usage no replication
#  extra-small: 16cpu,  35G memory, 750G disk 2 replicas
#  small:       42cpu,  83G memory, 750G disk 2 replicas
#  medium:      70cpu, 171G memory, 910G disk 2 replicas

#
# Customization environment variables
#
: "${OCPLOG_CHANNEL:=stable}"  # install channel
: "${OCPLOG_SIZE:=demo}"
# unit is days, 4 to handle anything that might have happened over the weekend
: "${OCPLOG_MAX_RETENTION:=4}"   
: "${OCPLOG_MAX_RETENTION_APP:=${OCPLOG_MAX_RETENTION}}"
: "${OCPLOG_MAX_RETENTION_INFRA:=${OCPLOG_MAX_RETENTION}}"
: "${OCPLOG_MAX_RETENTION_AUDIT:=${OCPLOG_MAX_RETENTION}}"
# https://docs.openshift.com/container-platform/4.15/observability/logging/log_storage/cluster-logging-loki.html#loki-rate-limit-errors_cluster-logging-loki
: "${OCPLOG_MAX_INGEST_BURST:=16}"
: "${OCPLOG_MAX_INGEST_RATE:=8}"
# https://docs.openshift.com/container-platform/4.15/observability/logging/log_storage/cluster-logging-loki.html#logging-creating-new-group-cluster-admin-user-role_cluster-logging-loki
: "${OCPLOG_USERS:=$(oc whoami)}"
# object storage settings
: "${OCPLOG_STORAGE_TYPE:=s3}"
: "${OCPLOG_STORAGE_CLASS:=ocs-storagecluster-ceph-rgw}"
# secret containing credentials for object storage (content varies per object storage implementation)
: "${OCPLOG_STORAGE_SECRET:=logging-loki-storage}"
# limit LOKI to nodes with these labels, set to "none" to allow to run on any node
: "${OCPLOG_NODE_SELECTOR_LABEL:=node-role.kubernetes.io/infra}"
# Allow LOKI on control plane nodes?  Questionable option, and not recommended in production
#OCPLOG_ON_CONTROL_PLANE=node-role.kubernetes.io/control-plane
# LOKI needs file storage too for temporary files
if [[ -z "${OCPLOG_TMP_STORAGE_CLASS}" ]]; then
  OCPLOG_TMP_STORAGE_CLASS=$(oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
  if [[ -z "${OCPLOG_TMP_STORAGE_CLASS}" ]]; then
    OCPLOG_TMP_STORAGE_CLASS=$(oc get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep 'rbd$')
    if [[ -z "${OCPLOG_TMP_STORAGE_CLASS}" ]]; then
      echo "WARNING: Could not find a suitable temporary storage class for logging."
      OCPLOG_TMP_STORAGE_CLASS=$(oc get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -v '^local' | head -1)
      if [[ -z "${OCPLOG_TMP_STORAGE_CLASS}" ]]; then
        echo "ERROR: No suitable storage class for LOKI temporary storage found"
        exit $LINENO
      fi
    fi
  fi
  echo "INFO: Using ${OCPLOG_TMP_STORAGE_CLASS} for logging temporary storage"
fi

if [[ "${OCPLOG_NODE_SELECTOR_LABEL}" != "none" ]]; then
  if [[ -z "$(oc get no -l ${OCPLOG_NODE_SELECTOR_LABEL} -o jsonpath='{.items[*].metadata.name}')" ]]; then
    echo "INFO: NodeSelectors are disabled because there are no nodes labeled with ${OCPLOG_NODE_SELECTOR_LABEL}"
    OCPLOG_NODE_SELECTOR_LABEL=none
  fi
fi

#Attempt to validate the provided config
OCPLOG_USERS=$(echo ${OCPLOG_USERS} | sed -r 's/[ ,]*$//; s/[ ,]+/, /g; s/://g')
b=$(echo ${OCPLOG_USERS} | egrep '\s')
if [[ -n "$b" ]]; then
  echo "ERROR: OCPLOG_USERS cannot contain whitespace"
  exit $LINENO
fi
b=$(echo ${OCPLOG_STORAGE_TYPE} | egrep -v '^s3$|^azure$|^gcs$|^swift$')
if [[ -n "$b" ]]; then
  echo "ERROR: Incorrect OCPLOG_STORAGE_TYPE $b"
  echo "  OCPLOG_STORAGE_TYPE must be one of: [ s3, azure, gcs, swift ]"
  exit $LINENO
fi
if [[ "${OCPLOG_STORAGE_CLASS}" == "ocs-storagecluster-ceph-rgw" ]]; then
  sc=$(oc get sc ${OCPLOG_STORAGE_CLASS} -o jsonpath='{.metadata.name}')
  if [[ -z "$sc" ]]; then
    echo ERROR: OCPLOG_STORAGE_CLASS is set to ${OCPLOG_STORAGE_CLASS} but that storage class does not exist.
    exit $LINENO
  fi
  OCPLOG_STORAGE_TYPE=s3
  s=$(oc get secret --ignore-not-found -n openshift-logging ${OCPLOG_STORAGE_SECRET})
  if [[ -z "$s" ]]; then
    use_odf_bucketclaim=true
  fi
else
  sc=$(oc get sc ${OCPLOG_STORAGE_CLASS} -o jsonpath='{.metadata.name}')
  if [[ -z "$sc" ]]; then
    echo "WARNING: OCPLOG_STORAGE_CLASS is set to ${OCPLOG_STORAGE_CLASS} but that storage class does not exist."
  fi
  obc=$(oc get crd --ignore-not-found objectbucketclaims.objectbucket.io -o jsonpath='{.metadata.name}')
  if [[ -z "$obc" ]]; then
    s=$(oc get secret -n openshift-logging ${OCPLOG_STORAGE_SECRET})
    if [[ -z "$s" ]]; then
      echo "ERROR: ODF is not installed and cannot find the secret '${OCPLOG_STORAGE_SECRET}'"
      echo "       in the project openshift-logging."
      echo "       Configure storage logging storage first as described in"
      echo '       https://docs.openshift.com/container-platform/4.15/observability/logging/log_storage/installing-log-storage.html#logging-loki-storage_installing-log-storage'
      exit $LINENO
    elif [[ -z "${OCPLOG_BLIND_OVERRIDE}" ]]; then
      echo "WARNING: Found OCPLOG_STORAGE_TYPE ${OCPLOG_STORAGE_TYPE}"
      echo "  Configuration is in secret ${OCPLOG_STORAGE_SECRET}"
      echo "  Additional OCP logging modifications/patching may be required after the script"
      echo "  completes. Set env var OCPLOG_BLIND_OVERRIDE=1 to acknowledge and continue."
      exit $LINENO
    fi
  fi
fi


cat << EOF | oc apply --validate -f -
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: openshift-logging
  annotations:
    openshift.io/node-selector: ""
  labels:
    openshift.io/cluster-monitoring: "true"
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cluster-logging
  namespace: openshift-logging 
spec:
  targetNamespaces:
  - openshift-logging 
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-logging
  namespace: openshift-logging 
spec:
  channel: ${OCPLOG_CHANNEL}
  name: cluster-logging
  source: redhat-operators 
  sourceNamespace: openshift-marketplace
EOF

echo -n 'Waiting for OpenShift Logging Operator to be installed...'
while true; do
  s=$(oc get csvs -n openshift-logging -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift Logging")].status.phase}')
  if [[ "$s" == "Succeeded" ]]; then break; fi
  echo -n .
  sleep 5
done
echo done


cat << EOF | oc apply --validate -f -
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: openshift-operators-redhat
  annotations:
    openshift.io/node-selector: ""
  labels:
    openshift.io/cluster-monitoring: "true"
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-operators-redhat
  namespace: openshift-operators-redhat
spec:
  upgradeStrategy: Default
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/loki-operator.openshift-operators-redhat: ""
  name: loki-operator
  namespace: openshift-operators-redhat
spec:
  channel: ${OCPLOG_CHANNEL} 
  installPlanApproval: Automatic
  name: loki-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  config:
    nodeSelector:
      ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
EOF

if [[ "${OCPLOG_NODE_SELECTOR_LABEL}" == "none" ]]; then
  oc patch Subscription loki-operator --type json -p '[{"op": "remove", "path": "/spec/config"}]'
fi

echo -n 'Waiting for OpenShift Loki Operator to be installed...'
while true; do
  s=$(oc get csvs -n openshift-operators-redhat -o jsonpath='{.items[?(@.spec.displayName=="Loki Operator")].status.phase}')
  if [[ "$s" == "Succeeded" ]]; then break; fi
  echo -n .
  sleep 5
done
echo done


#Logging Permissions
cat << EOF | oc apply --validate -f -
---
apiVersion: user.openshift.io/v1
kind: Group
metadata:
  name: cluster-admin
users: [ ${OCPLOG_USERS} ]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: cluster-admin
rules:
- apiGroups:
  - '*'
  resources:
  - '*'
  verbs:
  - '*'
- nonResourceURLs:
  - '*'
  verbs:
  - '*'
EOF


obcname=loki-bucket-odf
if [[ -n "${use_odf_bucketclaim}" ]]; then

  cat << EOF | oc apply --validate -f -
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: ${obcname}
  namespace: openshift-logging
spec:
  generateBucketName: ${obcname}
  storageClassName: ${OCPLOG_STORAGE_CLASS}
EOF

  echo -n 'Waiting for OpenShift LOKI ObjectBucketClaim to be ready...'
  while true; do
    s=$(oc get ObjectBucketClaim --ignore-not-found -n openshift-logging ${obcname} -o jsonpath='{.status.phase}')
    if [[ "$s" == "Bound" ]]; then break; fi
    echo -n .
    sleep 5
  done
  while true; do
    n=$(oc get cm --ignore-not-found -n openshift-logging ${obcname} -o jsonpath='{.metadata.name}')
    if [[ -n "$n" ]]; then break; fi
    echo -n .
    sleep 5
  done
  while true; do
    n=$(oc get secret --ignore-not-found -n openshift-logging ${obcname} -o jsonpath='{.metadata.name}')
    if [[ -n "$n" ]]; then break; fi
    echo -n .
    sleep 5
  done
  echo done

fi   #end of ODF bucket claim


n=$(oc get secret --ignore-not-found -n openshift-logging ${obcname} -o jsonpath='{.metadata.name}')
if [[ -n "$n" ]]; then

  bc="oc get cm -n openshift-logging ${obcname} -o jsonpath="
  bs="oc get secret -n openshift-logging ${obcname} -o jsonpath="
  ep="https://$(${bc}'{.data.BUCKET_HOST}'):$(${bc}'{.data.BUCKET_PORT}')"
  cat << EOF | oc apply --validate -f -
apiVersion: v1
kind: Secret
metadata:
  name: ${OCPLOG_STORAGE_SECRET}
  namespace: openshift-logging
type: Opaque
data:
  access_key_id: $(${bs}'{.data.AWS_ACCESS_KEY_ID}')
  access_key_secret: $(${bs}'{.data.AWS_SECRET_ACCESS_KEY}')
  bucketnames: $(${bc}'{.data.BUCKET_NAME}' | base64 | tr -d '\n')
  endpoint: $(echo -n $ep | base64 | tr -d '\n')
EOF

fi


cat << EOF | oc apply --validate -f -
apiVersion: loki.grafana.com/v1
kind: LokiStack
metadata:
  name: logging-loki 
  namespace: openshift-logging
spec:
  size: 1x.${OCPLOG_SIZE}
  storage:
    schemas:
    - effectiveDate: '2023-10-15'
      version: v13
    secret:
      name: ${OCPLOG_STORAGE_SECRET} 
      type: ${OCPLOG_STORAGE_TYPE}
  storageClassName: ${OCPLOG_TMP_STORAGE_CLASS}
  tenants:
    mode: openshift-logging
  limits:
    global:
      ingestion:
        ingestionBurstSize: ${OCPLOG_MAX_INGEST_BURST}
        ingestionRate: ${OCPLOG_MAX_INGEST_RATE}
      retention:
        days: ${OCPLOG_MAX_RETENTION}
        streams:
        - priority: 1
          days: ${OCPLOG_MAX_RETENTION_APP}
          selector: >-
            { log_type="application" }
        - days: ${OCPLOG_MAX_RETENTION_INFRA}
          selector: >-
            { log_type="infrastructure" }
        - days: ${OCPLOG_MAX_RETENTION_AUDIT}
          selector: >-
            { log_type="audit" }
  template:
    compactor: 
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    distributor:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    gateway:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    indexGateway:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    ingester:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    querier:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    queryFrontend:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
    ruler:
      nodeSelector:
        ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
      tolerations:
      - key: node.ocs.openshift.io/storage
        operator: Equal
        value: "true"
        effect: NoSchedule
EOF

if [[ ${OCPLOG_STORAGE_CLASS} == ocs-storagecluster-ceph-rgw ]]; then
  #ODF uses openshift service CA for their bucket TLS
  oc patch LokiStack logging-loki -n openshift-logging --type json\
     -p '[{"op": "add", "path": "/spec/storage/tls", "value": {"caName": "openshift-service-ca.crt"}}]'
fi

if [[ "${OCPLOG_NODE_SELECTOR_LABEL}" == "none" ]]; then
  cat <<EOF | oc patch LokiStack logging-loki -n openshift-logging --type json --patch-file=/dev/stdin
[
  {"op": "remove", "path": "/spec/template/compactor/nodeSelector"},
  {"op": "remove", "path": "/spec/template/distributor/nodeSelector"},
  {"op": "remove", "path": "/spec/template/gateway/nodeSelector"},
  {"op": "remove", "path": "/spec/template/indexGateway/nodeSelector"},
  {"op": "remove", "path": "/spec/template/ingester/nodeSelector"},
  {"op": "remove", "path": "/spec/template/querier/nodeSelector"},
  {"op": "remove", "path": "/spec/template/queryFrontend/nodeSelector"},
  {"op": "remove", "path": "/spec/template/ruler/nodeSelector"}
]
EOF
fi
if [[ -n "${OCPLOG_ON_CONTROL_PLANE}" ]]; then
  cat <<EOF | oc patch LokiStack logging-loki -n openshift-logging --type json --patch-file=/dev/stdin
[
  {"op": "add", "path": "/spec/template/compactor/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/distributor/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/gateway/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/indexGateway/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/ingester/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/querier/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/queryFrontend/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}},
  {"op": "add", "path": "/spec/template/ruler/tolerations/0",
                "value": {"key":"${OCPLOG_ON_CONTROL_PLANE}", "operator":"Exists"}}
]
EOF
fi

echo -n 'Waiting for OpenShift LOKI stack to be ready...'
while true; do
  s=$(oc get LokiStack logging-loki -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [[ "$s" == "True" ]]; then break; fi
  echo -n .
  sleep 5
done
echo done

cat << EOF | oc apply --validate -f -
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  managementState: Managed
  logStore:
    type: lokistack
    lokistack:
      name: logging-loki
  visualization:
    type: ocp-console
    nodeSelector:
      ${OCPLOG_NODE_SELECTOR_LABEL}: "${OCPLOG_NODE_SELECTOR_VALUE}"
    tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
      effect: NoSchedule
  collection:
    type: vector
EOF

if [[ "${OCPLOG_NODE_SELECTOR_LABEL}" == "none" ]]; then
  oc patch ClusterLogging instance -n openshift-logging --type json -p '[{"op": "remove", "path": "/spec/visualization/nodeSelector"}]'
fi
if [[ -n "${OCPLOG_ON_CONTROL_PLANE}" ]]; then
  oc patch ClusterLogging instance -n openshift-logging --type json -p \
    '[{"op": "add", "path": "/spec/visualization/tolerations/0", "value": {"key":"'${OCPLOG_ON_CONTROL_PLANE}'", "operator":"Exists"}}]'
fi


echo -n 'Waiting for OpenShift Logging Cluster to be ready...'
while true; do
  s=$(oc get ClusterLogging instance --ignore-not-found -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$s" == "True" ]; then break; fi
  sleep 5;
  echo -n .
done
echo done


#Enable logging on the OpenShift console
p=$(oc get console.operator cluster -o jsonpath='{.spec.plugins[?(@=="logging-view-plugin")]}')
if [[ -z "$p" ]]; then
  oc patch console.operator cluster --type json -p '[{"op": "add", "path": "/spec/plugins/0", "value": "logging-view-plugin"}]'
fi 

