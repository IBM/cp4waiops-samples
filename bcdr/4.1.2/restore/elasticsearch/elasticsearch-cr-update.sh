#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

source $WORKDIR/common/common-utils.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
rwx_sc=$(oc get pvc user-home-pvc -n $namespace -o jsonpath='{.spec.storageClassName}')

rm -f $WORKDIR/restore/elasticsearch/elasticsearch-cr-patch-copy.json

cp $WORKDIR/restore/elasticsearch/elasticsearch-cr-patch.json $WORKDIR/restore/elasticsearch/elasticsearch-cr-patch-copy.json

# Updating elastisearch cr for elasticsearch backup
sed -i "s/STORAGE_CLASS/$rwx_sc/g" $WORKDIR/restore/elasticsearch/elasticsearch-cr-patch-copy.json
   
# Updating elastisearch cr for elasticsearch backup
INDEX=$(oc get elasticsearches.elastic.automation.ibm.com iaf-system -n $namespace -o json  | jq '.spec.nodegroupspecs[0].config | map(.value == "/usr/share/elasticsearch/snapshots/es-backup") | index(true)')
if [ "$INDEX" = "null" ]; then
   echo "[INFO] $(date) Backup path is not registered previously, registering"
   oc patch --type=json elasticsearches.elastic.automation.ibm.com iaf-system  -n $namespace -p '''[{ "op": "add","path": "/spec/nodegroupspecs/0/config/-", "value": {"key" : "path.repo", "value": "/usr/share/elasticsearch/snapshots/es-backup"}}]'''
else
   echo "[INFO] $(date) Backup path is already registered"
fi
oc patch elasticsearches.elastic.automation.ibm.com iaf-system  -n $namespace --patch-file $WORKDIR/restore/elasticsearch/elasticsearch-cr-patch-copy.json --type=merge
echo "[INFO] $(date) elastisearch CR update script execution is completed, wait till all the elasticsearch pods are restarted"
