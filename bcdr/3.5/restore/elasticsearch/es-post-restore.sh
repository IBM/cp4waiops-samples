#!/bin/bash
echo "[INFO] $(date) ############## Elasticsearch pre-restore process has started ##############"

namespace=$(cat ../../common/aiops-config.json | jq -r '.aiopsNamespace')

oc delete pod es-backup -n $namespace 2> /dev/null
oc delete cm es-bcdr-config -n $namespace 2> /dev/null