#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#
echo "[INFO] $(date) ############## Infrastructure Management restore started ##############"

source $WORKDIR/restore/restore-utils.sh
source $WORKDIR/common/common-utils.sh
source $WORKDIR/common/prereq-check.sh

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')

#Reading backup name from config file
backupName=$(cat $WORKDIR/restore/restore-data.json | jq -r '.backupName')
imInstallCrName=$(oc get IMInstall -n $namespace --no-headers | cut -d " " -f 1)

imRestoreNamePrefix="im-restore"
imRestoreLabel="im.cp4aiops.ibm.com/backup=t"
echo "[INFO] $(date) namespace: $namespace, backupName: $backupName, imRestoreNamePrefix: $imRestoreNamePrefix, imRestoreLabel: $imRestoreLabel"

echo "[INFO] $(date) Deleting IM resources which needs to be restored if exists"
oc delete IMInstall $imInstallCrName -n $namespace 2> /dev/null
oc delete all -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete cm -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete secret -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete sa -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete pvc -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete Role -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete RoleBinding -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null
oc delete ManageIQ -l im.cp4aiops.ibm.com/backup=t -n $namespace 2> /dev/null

echo "[INFO] $(date) Waiting for some time after deleting IM resources which needs to be restored"
wait "120"

imInstallCrName=$(oc get IMInstall -n $namespace --no-headers | cut -d " " -f 1)
echo "[INFO] $(date) IMInstall CR name is $imInstallCrName"
if [ -z "$imInstallCrName" ]; then
      echo -e "[INFO] $(date) IMInstall CR does not exist so proceeding with IM restore"
else
      echo -e "[INFO] $(date) IMInstall CR exists so restore can not be done, cleanup IM related resources by deleting IMInstall CR and then proceed with IM restore"
      exit 1
fi

echo "[INFO] $(date) Performing velero restore for im"
performVeleroRestore $imRestoreNamePrefix $backupName $namespace $imRestoreLabel
restoreReturnValue=$?
echo "Velero restore return value is $restoreReturnValue"
if [ $restoreReturnValue -ne 0 ]; then
      echo "[ERROR] $(date) Velero restore failed, hence exiting"
      exit 1
fi

echo "[INFO] $(date) Check if required pvc is created through velero restore or not"
checkPvcStatus $namespace "postgresql"

echo "[INFO] $(date) Changing IM applicationDomain"
imInstallCrName=$(oc get IMInstall -n $namespace --no-headers | cut -d " " -f 1)
ingressSubdomain=$(oc whoami --show-console | cut -c 35-)
applicationDomain="inframgmtinstall".$ingressSubdomain
oc patch IMInstall $imInstallCrName -n $namespace -p "{\"spec\": {\"applicationDomain\": \"$applicationDomain\"}}" --type=merge

echo "[WARNING] $(date) Infrastructure Management restore is done, please wait till all IM pods are ready"
# Here we can add code till IM pods are ready, but it will increase the script execution time

echo "[INFO] $(date) ############## Infrastructure Management restore Completed ##############"
