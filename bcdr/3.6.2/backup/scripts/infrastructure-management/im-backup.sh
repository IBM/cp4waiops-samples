#!/bin/bash
echo "[INFO] $(date) ############## Infrastructure Management backup script execution started ##############"

BASEDIR=$(dirname "$0")
cd $BASEDIR
CURRENT=$(pwd)
echo $CURRENT

namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
imInstallCrName=$(oc get IMInstall -n $namespace --no-headers | cut -d " " -f 1)

echo "[INFO] $(date) Tagging required Infrastructure Management resources for backup"
oc label all -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label cm -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label secret -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label sa -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label pvc -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label Role -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label RoleBinding -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label ManageIQ -l manageiq.org/backup=t im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace
oc label IMInstall $imInstallCrName im.cp4aiops.ibm.com/backup=t cp4aiops.ibm.com/backup=t --overwrite=true -n $namespace

echo "[INFO] $(date) ############## Infrastructure Management backup script execution completed ##############"
