#!/bin/sh
set -e

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE="aiops"
fi

kubectl delete job aiops-storage-benchmark -n ${NAMESPACE} --ignore-not-found
kubectl delete persistentvolumeclaim aiops-storage-benchmark -n ${NAMESPACE} --ignore-not-found
