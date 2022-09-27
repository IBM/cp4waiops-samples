#!/bin/bash
echo "[INFO] $(date) ############## Backup process started ##############"

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source $WORKDIR/common/prereq-check.sh
source utils.sh
source $WORKDIR/common/common-utils.sh

V_FALSE=FALSE
IS_AIOPS_COMPONENT_ENABLED=$(IsComponentEnabled "AIOPS")
IS_IA_COMPONENT_ENABLED=$(IsComponentEnabled "IA")
namespace=$(cat $WORKDIR/common/aiops-config.json | jq -r '.aiopsNamespace')
rwx_sc=$(oc get pvc user-home-pvc -n $namespace -o jsonpath='{.spec.storageClassName}')

rm -rf /tmp/backup-result.json 2> /dev/null
cp backup-result-original.json /tmp/backup-result.json

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [AIOPS] is not enabled, hence skipping AIOPS related backup steps"
else
   echo "[INFO] $(date) Component [AIOPS] is enabled, hence performing AIOPS related backup steps"
   
   echo "[INFO] $(date) Updating automationbase CR for elasticsearch backup"
   elasticsearch/automationbase-cr-update.sh


   # Checking if the cluster is in good condition to take backup or not
   echo -e "[INFO] $(date) Checking if required PODs for CP4WAIOPS are in Running/Ready state or not"
   aiopsPodStatus $namespace

   echo -e "[INFO] $(date) Checking if required PVCs for CP4WAIOPS are in Bound state or not"
   pvcNames=$(cat $WORKDIR/common/prereq-check-details.json | jq -r  .aiopsPvc[].pvcName)
   for pvc in $pvcNames; do
	        checkPvcStatus  $namespace $pvc
	        pvcCheckReturnValue=$?
	       if [ $pvcCheckReturnValue -ne 0 ]; then
             echo "[ERROR] $(date) PVC check failed with return value $pvcCheckReturnValue"
             exit 1
          fi
   done

   echo -e "[INFO] $(date) Checking if required CRs for CP4WAIOPS are in expected state or not"
   aiopsStatus $namespace

   echo -e "[INFO] $(date) Verifying if the required api calls for elasticsearch snapshot operation are exposed or not"
   oc get automationbase -n $namespace automationbase-sample -o yaml | grep -i create_snapshot_action
   if [ $? -eq 0 ]; then
      echo -e "[INFO] $(date) Required api calls for elasticsearch snapshot operation are exposed"
   else
      echo -e  "[ERROR] $(date) Required api calls for elasticsearch snapshot operation are not exposed, hence exiting!"
      exit 1
   fi

   # Take cassandra backup
   cassandra/scripts/cassandra-backup.sh
fi

# Perform the required pre backup tasks such as scalling down the required pods
$CURRENT/pre-backup.sh

#Crate cs mongodump
$CURRENT/common-services/create-mongo-dump.sh

# Take metastore backup
$CURRENT/metastore/metastore-backup.sh

if [ "$IS_AIOPS_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [AIOPS] is not enabled, hence skipping AIOPS related backup steps"
else
   echo "[INFO] $(date) Component [AIOPS] is enabled, hence performing AIOPS related backup steps"
   # Take postgresql backup
   #postgres/ibm-postgres-backup.sh
   postgres/edb-postgres-backup.sh

   # Take elasticsearch snapshot
   $CURRENT/elasticsearch/es-backup.sh

   # Take other required resources backup
   other-resources/tunnel-cr-backup.sh

   # Take IBM vault backup
   vault/ibm-vault-backup.sh
fi

if [ "$IS_IA_COMPONENT_ENABLED" = "$V_FALSE" ]; then
   echo "[INFO] $(date) Component [IA] is not enabled, hence skipping IA related backup steps"
else
   echo "[INFO] $(date) Component [IA] is enabled, hence performing IA related backup steps"
   # Take infrastructure management backup
   infrastructure-management/im-backup.sh
fi


#Adding labels to the required resources
$CURRENT/add-label-to-resources.sh

# Add annotion to pod
$CURRENT/add-annotation-to-pod.sh

# Trigger backup
$CURRENT/trigger-backup.sh

# Perform the required post backup tasks such as scalling up the required pods
$CURRENT/post-backup.sh

$CURRENT/backup-result.sh
echo "[INFO] $(date) ############## Backup Result Summary ##############"
cat /tmp/backup-result.json
oc delete configmap backup-result-config -n $namespace 2> /dev/null
oc create configmap backup-result-config --from-file=/tmp/backup-result.json -n $namespace

echo "[INFO] $(date) ############## Backup process completed ##############"
