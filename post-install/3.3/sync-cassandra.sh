#!/bin/bash
set -eo pipefail

DRY_RUN=""

GREEN="\x1B[0;32m"
ORANGE="\x1B[0;33m"
RED="\x1B[0;31m"
NC="\x1B[0m"
BOLD="\x1B[1m"

CASSANDRA_CLIENT_DEPLOYMENTS=(
  aiops-ir-analytics-metric-api
  aiops-ir-analytics-metric-spark
  aiops-ir-analytics-spark-master
  aiops-ir-analytics-spark-pipeline-composer
  aiops-ir-analytics-spark-worker
  aiops-ir-core-archiving
  aiops-ir-core-esarchiving
  aiops-ir-lifecycle-policy-grpc-svc
  aiops-ir-lifecycle-policy-registry-svc
  aiops-topology-layout
  aiops-topology-merge
  aiops-topology-status
)
CASSANDRA_CLIENT_REPLICAS=( )

CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS=(
  aiops-ir-analytics-classifier
  aiops-ir-analytics-probablecause
  aiops-topology-topology
)
CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS=( )

CASSANDRA_CLIENT_JOBS=(
  aiops-ir-lifecycle-create-policies-job
)

CASSANDRA_SCHEMA_CREATOR_JOBS=(
  aiops-ir-analytics-cassandra-setup
  aiops-ir-core-archiving-setup
  aiops-ir-lifecycle-policy-registry-svc-job
)

OPERATORS=(
  ir-core-operator-controller-manager
  ibm-ir-ai-operator-controller-manager
  ir-lifecycle-operator-controller-manager
  asm-operator
)
OPERATOR_REPLICA=( )

function waitForStatus() {
  KIND=$1
  NAME=$2
  RETRIES=$3
  SLEEP=$4
  JSONPATH=${5:-'{.status.conditions[?(@.type=="Ready")].status}'}
  CONDITION=${6:-True}
  NAMESPACE=${7:-$(oc project -q)}

  count=0
  while :
  do
    echo "Get ${KIND}/${NAME} status"
    STATUS=$(oc get ${KIND}/${NAME} -o jsonpath="${JSONPATH}" || echo 'False')

    if [[ "${CONDITION}" == "${STATUS}" ]]; then
      echo "${KIND}/${NAME} is ready"
      break
    else
      ((count+=1))
      if (( count <= RETRIES )); then
        echo "  Status: ${STATUS}, Recheck $count of ${RETRIES} in ${SLEEP} sec."
        sleep "${SLEEP}"
      else
        echo "Waiting for ${KIND}/${NAME} to be ready timed out"
        exit 1
      fi
    fi
  done
}

function printRollback() {
  echo -e "" >&2
  echo -e "============================" >&2
  echo -e "${RED}Process cancelled${NC}" >&2
  echo -e "============================" >&2
  echo -e "" >&2
  echo -e "${GREEN}Run the following to roll-back:${NC}" >&2
  echo -e "" >&2

  if ! [ -z "${CASSANDRA_REPLICAS}" ]; then
    echo -e "oc scale sts aiops-topology-cassandra --replicas=${CASSANDRA_REPLICAS} --timeout 10m"  >&2
  fi

  for i in "${!CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[@]}"; do
    if ! [ -z "${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]}" ]; then
      echo -e "oc scale deploy ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} --replicas=${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]} --timeout 10m"
    fi
  done

  for i in "${!CASSANDRA_CLIENT_DEPLOYMENTS[@]}"; do
    if ! [ -z "${CASSANDRA_CLIENT_REPLICAS[$i]}" ]; then
      echo -e "oc scale deploy ${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} --replicas=${CASSANDRA_CLIENT_REPLICAS[$i]} --timeout 10m"
    fi
  done

  for i in "${!OPERATORS[@]}"; do
    if ! [ -z "${OPERATOR_REPLICAS[$i]}" ]; then
      echo -e "oc scale deploy ${OPERATORS[$i]} --replicas=${OPERATOR_REPLICAS[$i]} --timeout 10m"
    fi
  done
}

trap printRollback ERR
trap printRollback SIGINT

echo -e "${GREEN}-o Scale down operators${NC}" >&2
for i in "${!OPERATORS[@]}"; do
  OPERATOR_REPLICAS[$i]=$(oc get deploy ${OPERATORS[$i]} -o jsonpath='{.spec.replicas}')

  echo -e "  Scaling deployment/${OPERATORS[$i]} from ${OPERATOR_REPLICAS[$i]} to 0 replicas" >&2
  ${DRY_RUN} oc scale deploy ${OPERATORS[$i]} --replicas=0 --timeout 10m
done

echo -e "${GREEN}-o Scale down all cassandra clients${NC}" >&2
for i in "${!CASSANDRA_CLIENT_DEPLOYMENTS[@]}"; do
  CASSANDRA_CLIENT_REPLICAS[$i]=$(oc get deploy ${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} -o jsonpath='{.spec.replicas}')

  echo -e "  Scaling deployment/${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} from ${CASSANDRA_CLIENT_REPLICAS[$i]} to 0 replicas" >&2
  ${DRY_RUN} oc scale deploy ${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} --replicas=0 --timeout 10m
done

echo -e "${GREEN}-o Scale down all cassandra schema creators${NC}" >&2
for i in "${!CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[@]}"; do
  CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]=$(oc get deploy ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} -o jsonpath='{.spec.replicas}')

  echo -e "  Scaling deployment/${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} from ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]} to 0 replicas" >&2
  ${DRY_RUN} oc scale deploy ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} --replicas=0 --timeout 10m
done

echo -e "${GREEN}-o Scale down cassandra${NC}" >&2
CASSANDRA_REPLICAS=$(oc get sts aiops-topology-cassandra -o jsonpath='{.spec.replicas}')
echo -e "  Scaling statefulset/aiops-topology-cassandra from ${CASSANDRA_REPLICAS} to 0 replicas" >&2
${DRY_RUN} oc scale sts aiops-topology-cassandra --replicas=0 --timeout 10m

echo -e "${GREEN}-o Scale up cassandra${NC}" >&2
echo -e "  Scaling statefulset/aiops-topology-cassandra from 0 to ${CASSANDRA_REPLICAS} replicas" >&2
${DRY_RUN} oc scale sts aiops-topology-cassandra --replicas=${CASSANDRA_REPLICAS} --timeout 10m

echo -e "${GREEN}-o Wait for cassandra to be ready${NC}" >&2
${DRY_RUN} waitForStatus \
  sts \
  aiops-topology-cassandra \
  300 \
  10 \
  '{.status.readyReplicas}' \
  ${CASSANDRA_REPLICAS}

echo -e "${GREEN}-o Trigger schema creation jobs${NC}" >&2
for i in "${CASSANDRA_SCHEMA_CREATOR_JOBS[@]}"; do
  echo -e "  Replacing job/${i}" >&2

  JOB_JSON=$(
    oc get job ${i} \
      -o jsonpath='{.metadata.annotations.kubectl\.kubernetes\.io/last-applied-configuration}'
  )

  ${DRY_RUN} echo "${JOB_JSON}" | ${DRY_RUN} oc replace --force -f -
  ${DRY_RUN} oc annotate job ${i} kubectl.kubernetes.io/last-applied-configuration="${JOB_JSON}"

  echo -e "  ${GREEN}-o Wait for job to complete${NC}" >&2
  ${DRY_RUN} waitForStatus \
    job \
    ${i} \
    300 \
    10 \
    '{.status.conditions[?(@.type=="Complete")].status}'
done

echo -e "${GREEN}-o Scale up schema creation deployments${NC}" >&2
for i in "${!CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[@]}"; do
  echo -e "  Scaling deployment/${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} from 0 to ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]} replicas" >&2
  ${DRY_RUN} oc scale deploy ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} --replicas=${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]} --timeout 10m

  ${DRY_RUN} waitForStatus \
    deployment \
    ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS[$i]} \
    300 \
    10 \
    '{.status.readyReplicas}' \
    ${CASSANDRA_SCHEMA_CREATOR_DEPLOYMENTS_REPLICAS[$i]}
done

echo -e "${GREEN}-o Scale up client deployments${NC}" >&2
for i in "${!CASSANDRA_CLIENT_DEPLOYMENTS[@]}"; do
  echo -e "  Scaling deployment/${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} from 0 to ${CASSANDRA_CLIENT_REPLICAS[$i]} replicas" >&2
  ${DRY_RUN} oc scale deploy ${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} --replicas=${CASSANDRA_CLIENT_REPLICAS[$i]} --timeout 10m
done

echo -e "${GREEN}-o Scale up operator deployments${NC}" >&2
for i in "${!OPERATORS[@]}"; do
  echo -e "  Scaling deployment/${OPERATORS[$i]} from 0 to ${OPERATOR_REPLICAS[$i]} replicas" >&2
  ${DRY_RUN} oc scale deploy ${OPERATORS[$i]} --replicas=${OPERATOR_REPLICAS[$i]} --timeout 10m
done

echo -e "${GREEN}-o Wait for clients to become ready${NC}" >&2
for i in "${!CASSANDRA_CLIENT_DEPLOYMENTS[@]}"; do
  ${DRY_RUN} waitForStatus \
    deployment \
    ${CASSANDRA_CLIENT_DEPLOYMENTS[$i]} \
    300 \
    10 \
    '{.status.readyReplicas}' \
    ${CASSANDRA_CLIENT_REPLICAS[$i]}
done

echo -e "${GREEN}-o Wait for operators to become ready${NC}" >&2
for i in "${!OPERATORS[@]}"; do
  ${DRY_RUN} waitForStatus \
    deployment \
    ${OPERATORS[$i]} \
    300 \
    10 \
    '{.status.readyReplicas}' \
    ${OPERATOR_REPLICAS[$i]}
done
