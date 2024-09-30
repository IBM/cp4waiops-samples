#!/bin/sh
set -e

kubectl delete job storage-benchmark -n aiops-storage-benchmark --ignore-not-found
kubectl delete persistentvolumeclaim storage-benchmark -n aiops-storage-benchmark --ignore-not-found
kubectl delete namespace aiops-storage-benchmark --ignore-not-found
