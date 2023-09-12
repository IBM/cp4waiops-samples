#!/bin/bash
#
# © Copyright IBM Corp. 2022, 2023
# 
# 
#

## enable-insights
# this script will enable insights UI

## TODO: make variables overrideable

INSIGHTSUI_DEPLOY_NAME="aiops-insights-ui"
CLUSTER_NAME=$(oc cluster-info | grep running | awk '{print $NF}' | awk -F'.' '{print $2}')
echo "Using cluster $CLUSTER_NAME"

NS=$(oc get subscriptions.operators.coreos.com -A | grep aimanager-operator | awk '{print $1}')
echo "AIOps installation found in ${NS}"

INSTALL_INSTANCE=$(oc -n ${NS} get installation | grep Running | awk '{print $1}')
echo "AIOps installation instance: ${INSTALL_INSTANCE}"

ES_BINDING_SECRET="${INSTALL_INSTANCE}-elastic-secret"
KF_BINDING_SECRET="${INSTALL_INSTANCE}-kafka-secret"
echo "Using elastic search binding search named: ${ES_BINDING_SECRET}"
echo "Using kafka binding search named: ${KF_BINDING_SECRET}"

CR_INSTANCE_NAME="insightsui-instance"

# Wait for cr instance to come ready.
function wait-for-instance {
  local RETRIES=60
  local SLEEP_TIME=10

  echo "wait for ${CR_INSTANCE_NAME} to come ready..."
  while true; do
    sleep ${SLEEP_TIME}
    local IS_NOT_READY=$(oc -n ${NS} get insightsui ${CR_INSTANCE_NAME} -o jsonpath={.status.conditions[*].status} | grep False)

    if [[ ( ${RETRIES} -eq 0 ) && ( "${IS_NOT_READY}" ) ]]; then
        echo "timeout waiting for ${CR_INSTANCE_NAME} to come ready"
        exit 1
    fi
      
    if [[ "${IS_NOT_READY}" ]]; then
        echo "Still waiting for insights ui dashboard to come ready... (${RETRIES} left)"
        RETRIES=$(( RETRIES - 1 ))
    else
        break
    fi

      sleep ${SLEEP_TIME}
  done

  echo "${CR_INSTANCE_NAME} is ready!"
}

function get-image-from-deployment {
  local DEPLOY_NAME=$1
  local IMAGE_NAME=$2

  oc get -n ${NS} $(oc get -n ${NS} deploy -o name | grep ${DEPLOY_NAME}) -o jsonpath={.spec.template.metadata.annotations."olm\.relatedImage\.${IMAGE_NAME}"}
}

function check-deployment-done {
  local RETRIES=60
  local SLEEP_TIME=10

  local DEPLOYMENT_NAME=$1

  echo "wait for ${DEPLOYMENT_NAME} to finish..."
  while true; do
    sleep ${SLEEP_TIME}
    local IS_NOT_READY=$(oc -n ${NS} get deploy ${DEPLOYMENT_NAME} -o jsonpath={.status.conditions[*].status} | grep False)

    if [[ ( ${RETRIES} -eq 0 ) && ( "${IS_NOT_READY}" ) ]]; then
        echo "timeout waiting for ${DEPLOYMENT_NAME} to finish"
        exit 1
    fi
      
    if [[ "${IS_NOT_READY}" ]]; then
        echo "Still waiting for ${DEPLOYMENT_NAME} to finish... (${RETRIES} left)"
        RETRIES=$(( RETRIES - 1 ))
    else
        break
    fi

      sleep ${SLEEP_TIME}
  done

  echo "${DEPLOYMENT_NAME} is done!"
}

# Look to see if we already installed
if [ -z "$(oc get insightsui -o jsonpath={.items[*]})" ]
then
  echo "no instance of insights ui found... creating insights ui instance"

cat <<EOF | oc apply -f -
  apiVersion: consoleui.aiops.ibm.com/v1
  kind: InsightsUI
  metadata:
    name: ${CR_INSTANCE_NAME}
    namespace: ${NS}
  spec:
    license:
      accept: true
    size: small
    version: 1.0.0
    elasticSearch:
      bindingSecret: ${ES_BINDING_SECRET}
EOF

  wait-for-instance
else
  CR_INSTANCE_NAME=$(oc get insightsui -o jsonpath={.items[0].metadata.name})
  echo "An instance of insights UI already exists... using ${CR_INSTANCE_NAME} instance"
fi

CR_UID=$(oc -n ${NS} get InsightsUI ${CR_INSTANCE_NAME} -o jsonpath={.metadata.uid})

echo "creating data routing..."

DATAROUTER_DEPLOY_NAME="aiops-insights-ui-datarouting"
DATAROUTER_IMAGE=$(get-image-from-deployment ir-core-operator datarouting-service)
if [ "$DATAROUTER_IMAGE" == "" ]; then
    echo "could not find data routing image to use from deployment"
    exit 1
fi

cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${DATAROUTER_DEPLOY_NAME}
  namespace: ${NS}
  ownerReferences:
  - apiVersion: consoleui.aiops.ibm.com/v1
    blockOwnerDeletion: true
    controller: true
    kind: InsightsUI
    name: ${CR_INSTANCE_NAME}
    uid: ${CR_UID}
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app.kubernetes.io/component: common-datarouting
      app.kubernetes.io/instance: aiops
      component: saas-disable
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app.kubernetes.io/component: common-datarouting
        app.kubernetes.io/instance: aiops
        component: saas-disable
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: kubernetes.io/arch
                operator: In
                values:
                - amd64
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchLabels:
                  app.kubernetes.io/component: common-datarouting
                  app.kubernetes.io/instance: aiops
              topologyKey: kubernetes.io/hostname
            weight: 50
      containers:
      - env:
        - name: ELASTICSEARCH_BINDING
          value: /home/node/binding/elasticsearch
        - name: KAFKA_BROKERS
          valueFrom:
            secretKeyRef:
              key: bootstrapServers
              name: ${KF_BINDING_SECRET}
        - name: KAFKA_SASL_USERNAME
          valueFrom:
            secretKeyRef:
              key: username
              name: ${KF_BINDING_SECRET}
        - name: KAFKA_SASL_PASSWORD
          valueFrom:
            secretKeyRef:
              key: password
              name: ${KF_BINDING_SECRET}
        - name: KAFKA_SSL_CA
          valueFrom:
            secretKeyRef:
              key: caCertificate
              name: ${KF_BINDING_SECRET}
        - name: PIPELINES
          value: es-story-archive
        - name: LOGLEVEL
          value: info
        - name: LOGSTASH_SHARDS
          value: "1"
        - name: LOGSTASH_REPLICAS
          value: "0"
        - name: KAFKA_TOPICPREFIX
          value: cp4waiops-cartridge.
        - name: KAFKA_SSL_ENABLED
          value: "true"
        - name: KAFKA_SASL_MECHANISM
          valueFrom:
            secretKeyRef:
              key: authMechanism
              name: ${KF_BINDING_SECRET}
        image: ${DATAROUTER_IMAGE}
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 60
          successThreshold: 1
          timeoutSeconds: 20
        name: logstash
        ports:
        - containerPort: 8080
          protocol: TCP
        readinessProbe:
          failureThreshold: 1
          httpGet:
            path: /
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 20
          successThreshold: 1
          timeoutSeconds: 20
        resources:
          limits:
            cpu: "1"
            ephemeral-storage: 200Mi
            memory: 2800Mi
          requests:
            cpu: 200m
            ephemeral-storage: 50Mi
            memory: 1400Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          privileged: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /home/node/binding/elasticsearch
          name: elasticsearch-binding
          readOnly: true
        - mountPath: /home/node/tls/kafka
          name: kafka-ca
          readOnly: true
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext:
        runAsNonRoot: true
      serviceAccount: ${INSIGHTSUI_DEPLOY_NAME}
      serviceAccountName: ${INSIGHTSUI_DEPLOY_NAME}
      terminationGracePeriodSeconds: 30
      volumes:
      - name: elasticsearch-binding
        secret:
          defaultMode: 292
          secretName: ${ES_BINDING_SECRET}
      - name: kafka-ca
        secret:
          defaultMode: 292
          items:
          - key: caCertificate
            path: ca.crt
          secretName: ${KF_BINDING_SECRET}
EOF

check-deployment-done ${DATAROUTER_DEPLOY_NAME}
