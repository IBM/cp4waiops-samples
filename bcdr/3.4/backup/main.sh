#!/bin/bash

BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

source ../common/prereq-check.sh
namespace=$(cat ../common/aiops-config.json | jq -r '.aiopsNamespace')

# Checking if the cluster is in good condition to take backup or not
echo -e "Checking if required PODs for CP4WAIOPS are in Running/Ready state or not"
aiopsPodStatus $namespace

echo -e "Checking if required PVCs for CP4WAIOPS are in Bound state or not"
pvcNames=$(cat ../common/prereq-check-details.json | jq -r  .aiopsPvc[].pvcName)
for pvc in $pvcNames; do
	checkPvcStatus  $namespace $pvc
done

echo -e "Checking if required CRs for CP4WAIOPS are in expected state or not"
aiopsStatus $namespace

echo -e "Verifying if the required api calls for elasticsearch snapshot operation are exposed or not"
oc get automationbase -n $namespace automationbase-sample -o yaml | grep -i create_snapshot_action
if [ $? -eq 0 ]; then
   echo -e "Required api calls for elasticsearch snapshot operation are exposed"
else
   echo -e  "Required api calls for elasticsearch snapshot operation are not exposed, hence exiting!"
   exit 1
fi

# Take cassandra backup
cassandra/scripts/cassandra-backup.sh

# Perform the required pre backup tasks such as scalling down the required pods
$CURRENT/pre-backup.sh

#Crate cs mongodump
$CURRENT/common-services/create-mongo-dump.sh

# Take metastore backup
$CURRENT/metastore/metastore-backup.sh

# Take postgresql backup
postgres/ibm-postgres-backup.sh

# Take elasticsearch snapshot
$CURRENT/elasticsearch/es-backup.sh

# Take other required resources backup
other-resources/tunnel-cr-backup.sh

#Adding labels to the required resources
$CURRENT/add-label-to-resources.sh

# Add annotion to pod
$CURRENT/add-annotation-to-pod.sh

# Trigger backup
$CURRENT/trigger-backup.sh

# Perform the required post backup tasks such as scalling up the required pods
$CURRENT/post-backup.sh

echo "Backup process is Completed"
