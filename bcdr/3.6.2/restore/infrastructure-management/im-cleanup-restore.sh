#!/bin/bash
echo "[INFO] $(date) ############## Infrastructure Management cleanup steps started ##############"

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
imInstallCrName=$(oc get IMInstall -n $namespace --no-headers | cut -d " " -f 1)

echo "[INFO] $(date) Deleting IM resources which are restored"
oc delete IMInstall $imInstallCrName -n $namespace 2> /dev/null
oc delete all -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete cm -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete secret -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete sa -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete pvc -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete Role -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete RoleBinding -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete ManageIQ -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
echo "[INFO] $(date) Please wait until all IM related resources are deleted properly"
