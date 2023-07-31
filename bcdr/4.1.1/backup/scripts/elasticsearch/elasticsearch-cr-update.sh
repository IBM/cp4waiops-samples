#!/bin/bash
#
# IBM Confidential
# 5737-M96
# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

source $WORKDIR/common/common-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
rwx_sc=$(oc get pvc user-home-pvc -n $namespace -o jsonpath='{.spec.storageClassName}')

sed -i "s/STORAGE_CLASS/$rwx_sc/g" $WORKDIR/backup/scripts/elasticsearch/elasticsearch-cr-patch.json
   
# Updating elasticsearch cr for elasticsearch backup
sed -i "s/STORAGE_CLASS/$rwx_sc/g" $WORKDIR/backup/scripts/elasticsearch/elasticsearch-cr-patch.json
   
# Updating elasticsearch cr for elasticsearch backup
INDEX=$(oc get elasticsearches.elastic.automation.ibm.com iaf-system  -n $namespace -o json  | jq '.spec.nodegroupspecs[0].config | map(.value == "/usr/share/elasticsearch/snapshots/es-backup") | index(true)')
if [ "$INDEX" = "null" ]; then
   echo "[INFO] $(date) Backup path is not registered previously, registering"
   oc patch --type=json elasticsearches.elastic.automation.ibm.com iaf-system  -n $namespace -p '''[{ "op": "add","path": "/spec/nodegroupspecs/0/config/-", "value": {"key" : "path.repo", "value": "/usr/share/elasticsearch/snapshots/es-backup"}}]'''
else
   echo "[INFO] $(date) Backup path is already registered"
fi
oc patch elasticsearches.elastic.automation.ibm.com iaf-system  -n $namespace --patch-file $WORKDIR/backup/scripts/elasticsearch/elasticsearch-cr-patch.json --type=merge
echo "[INFO] $(date) Waiting till all elasticsearch pods are READY after updating backup path and snapshot location in elasticsearch CR"
wait "60"
checkPodReadynessV2 $namespace "app.kubernetes.io/name=elasticsearch" "60"
