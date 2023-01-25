#!/bin/bash
echo "[INFO] $(date) ############## Elasticsearch post-restore process has started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

oc delete pod es-backup -n $namespace 2> /dev/null
oc delete cm es-bcdr-config -n $namespace 2> /dev/null

echo "[INFO] $(date) ############## Elasticsearch post-restore process has completed ##############"

