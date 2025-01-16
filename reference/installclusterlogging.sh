#!/bin/bash
#
# © Copyright IBM Corp. 2023, 2024
# SPDX-License-Identifier: Apache2.0
#
#This reference script can be used to install the deprecated OpenShift
#  Logging with Elasticsearch as documented in:
#    https://docs.openshift.com/container-platform/4.15/observability/logging/cluster-logging-deploying.html#logging-es-deploy-cli_cluster-logging-deploying
#
#The script can be used in a production environment, but is not a substitute
#  for thorough planning or an understanding of the installation process and its
#  consequences.
#
#Important: Further customizations and modifications to this script are expected
#  to ensure that it aligns with your requirements.
#

#set -x

# FullRedundancy:     Elasticsearch fully replicates the primary shards for each index to every data node.
# MultipleRedundancy: Elasticsearch fully replicates the primary shards for each index to half of the data nodes.
# SingleRedundancy:   Elasticsearch makes one copy of the primary shards for each index. Logs are always available and
#                       recoverable as long as at least two data nodes exist.
# ZeroRedundancy:     Elasticsearch does not make copies of the primary shards. 
: "${OPENSHIFT_LOGGING_REDUNDANCY_POLICY:=ZeroRedundancy}"
: "${OPENSHIFT_LOGGING_ELASTICSEARCH_NODES:=1}"
: "${OPENSHIFT_LOGGING_ELASTICSEARCH_MEMORY:=8}"

# 4 days to handle anything that might have happened over the weekend
: "${OPENSHIFT_LOGGING_MAX_RETENTION:=4}"
: "${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_APP:=${OPENSHIFT_LOGGING_MAX_RETENTION}}"
: "${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_INFRA:=${OPENSHIFT_LOGGING_MAX_RETENTION}}"
: "${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_AUDIT:=${OPENSHIFT_LOGGING_MAX_RETENTION}}"

# ZeroRedundancy with 4 days for all categories with CP4AIOps running uses <120Gi, there is some buffer
#   for a very active AIOps, but a very active large install might need 300Gi for logs
: "${OPENSHIFT_LOGGING_STORAGE_SIZE:=200}"

# Set to any value to disable the route exposing elasticsearch 
#OPENSHIFT_LOGGING_NO_ELASTIC_ROUTE=true 

if [ -z "${OPENSHIFT_LOGGING_STORAGE_CLASS}" ]; then
  OPENSHIFT_LOGGING_STORAGE_CLASS=$(oc get sc -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
  if [ -z "${OPENSHIFT_LOGGING_STORAGE_CLASS}" ]; then
    OPENSHIFT_LOGGING_STORAGE_CLASS=$(oc get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep 'rbd$')
    if [ -z "${OPENSHIFT_LOGGING_STORAGE_CLASS}" ]; then
      echo "WARNING: Could not find a suitable storage class for logging, rolling the dice..."
      OPENSHIFT_LOGGING_STORAGE_CLASS=$(oc get sc -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | grep -v '^local' | head -1)
      if [ -z "${OPENSHIFT_LOGGING_STORAGE_CLASS}" ]; then
        echo "ERROR: No suitable storage class for logging found"; exit $LINENO
      fi
    fi
  fi
  echo "INFO: Using ${OPENSHIFT_LOGGING_STORAGE_CLASS} for logging storage"
fi


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
  name: openshift-operators-redhat
  namespace: openshift-operators-redhat
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
  name: elasticsearch-operator
  namespace: openshift-operators-redhat
spec:
  channel: stable
  installPlanApproval: Automatic
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  name: elasticsearch-operator
EOF


echo -n 'Waiting for OpenShift Elasticsearch Operator to be installed...'
pc=$(oc get project --no-headers -o jsonpath='{.items[*].metadata.name}' | wc -w)
while true; do
  cc=$(oc get csvs --all-namespaces -o 'jsonpath={range .items[?(@.spec.displayName=="OpenShift Elasticsearch Operator")]}{.status.phase}{"\n"}{end}' |grep 'Succeeded' | wc -l)
  if [ $cc -ge $pc ]; then break; fi
  echo -n .
  sleep 5
done
echo done


cat << EOF | oc apply --validate -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: cluster-logging
  namespace: openshift-logging
spec:
  channel: "stable"
  name: cluster-logging
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo -n 'Waiting for OpenShift Logging to be installed...'
while true; do
  s=$(oc get csvs -n openshift-logging -o jsonpath='{.items[?(@.spec.displayName=="Red Hat OpenShift Logging")].status.phase}')
  if [ "$s" == "Succeeded" ]; then break; fi
  sleep 5;
  echo -n .
done
echo done


#TODO: ClusterLogging does not allow nodeAffinity only nodeSelector.  The preference would be to run
#  on infrastructure nodes so that resources are not taken away from the application, but currently
#  this means manually calculating capacity 
#    elasticsearch:
#      nodeSelector:
#        node-role.kubernetes.io/infra: ''
#    kibana:
#      nodeSelector:
#        node-role.kubernetes.io/infra: ''
#As of 4.10/4.12 if nodes have 32Mb it should be safe to add the node selectors

#https://docs.openshift.com/container-platform/4.12/logging/config/cluster-logging-log-store.html
cat << EOF | oc apply --validate -f -
apiVersion: logging.openshift.io/v1
kind: ClusterLogging
metadata:
  name: instance
  namespace: openshift-logging
spec:
  managementState: Managed
  logStore:
    type: elasticsearch
    retentionPolicy:
      application:
        maxAge: ${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_APP}d
      infra:
        maxAge: ${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_INFRA}d
      audit:
        maxAge: ${OPENSHIFT_LOGGING_RETENTION_POLICY_MAX_AUDIT}d
    elasticsearch:
      nodeCount: ${OPENSHIFT_LOGGING_ELASTICSEARCH_NODES}
      storage:
        storageClassName: ${OPENSHIFT_LOGGING_STORAGE_CLASS}
        size: ${OPENSHIFT_LOGGING_STORAGE_SIZE}G
      resources:  #default CPU limits will be set by operator
        limits:
          memory: ${OPENSHIFT_LOGGING_ELASTICSEARCH_MEMORY}Gi
        requests:
          memory: ${OPENSHIFT_LOGGING_ELASTICSEARCH_MEMORY}Gi
      proxy:
        resources:  #default CPU limits will be set by operator
          limits:
            memory: 256Mi
          requests:
            memory: 256Mi
      redundancyPolicy: $OPENSHIFT_LOGGING_REDUNDANCY_POLICY
  visualization:
    type: kibana
    kibana:
      replicas: 1
  collection:
    type: fluentd
    fluentd: {}
---
apiVersion: logging.openshift.io/v1
kind: ClusterLogForwarder
metadata:
  name: instance
  namespace: openshift-logging
spec:
  pipelines: 
  - name: all-to-default
    inputRefs:
    - infrastructure
    - application
    - audit
    outputRefs:
    - default
EOF

echo -n 'Waiting for OpenShift Logging Cluster to be ready...'
while true; do
  s=$(oc get ClusterLogging instance --ignore-not-found -n openshift-logging -o jsonpath='{.status.logStore.elasticsearchStatus[0].cluster.status}')
  if [ "$s" == "green" ]; then break; fi
  sleep 5;
  echo -n .
done
echo done

echo -n 'Waiting for OpenShift Logging Forwarder to be ready...'
while true; do
  s=$(oc get ClusterLogForwarder instance --ignore-not-found -n openshift-logging -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$s" == "True" ]; then break; fi
  sleep 5;
  echo -n .
done
echo done


echo -en "ElasticSearch status:  "
oc exec -ti -n openshift-logging \
   $(oc get po -n openshift-logging -l name=cluster-logging-operator -o jsonpath='{.items[0].metadata.name}') \
   -- curl -sSk -H "Authorization: Bearer $(oc whoami -t)" https://elasticsearch:9200/_cat/health

if [ -n "${OPENSHIFT_LOGGING_NO_ELASTIC_ROUTE}" ]; then
  oc delete route --ignore-not-found -n openshift-logging elasticsearch
else
  echo "Exposing/Adding ElasticSearch route"
  cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: elasticsearch
  namespace: openshift-logging
spec:
  wildcardPolicy: None
  to:
    kind: Service
    name: elasticsearch
  tls:
    termination: reencrypt
    insecureEdgeTerminationPolicy: Redirect
    destinationCACertificate: |
$(oc get route -n openshift-logging kibana -o jsonpath='{.spec.tls.destinationCACertificate}' | sed 's/^/      /')
EOF
  curl -sSk -H "Authorization: Bearer $(oc whoami -t)" \
    https://$(oc get route -n openshift-logging elasticsearch -o jsonpath='{.spec.host}')/_cat/health
fi
