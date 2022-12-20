#!/bin/bash

source $WORKDIR/restore/cassandra/cassandra-utils.sh

echo "[INFO] $(date) Scaling down the ibm-ir-ai-operator-controller-manager deployment"
RC=$(oc get deployment ibm-ir-ai-operator-controller-manager  -n $namespace -o=jsonpath='{.spec.replicas}')
jsonstr=$jsonstr\"ibm-ir-ai-operator-controller-manager-RC\":$RC,
oc scale deploy ibm-ir-ai-operator-controller-manager -n $namespace  --replicas=0


deploymentList=$(oc get deployment -n $namespace --no-headers -o custom-columns=":metadata.name"|grep -i "aiops-topology\|aiops-ir-analytics"|grep -v cassandra)

#Saving the original replica count for metric and topology deployments before Cassandra backup
echo "[INFO] $(date) Saving the original replica count for metric and topology deployments before Cassandra backup"
for deployment in $deploymentList; do
    
    {
    #TRY
        RC=$(oc get deployment $deployment  -n $namespace -o=jsonpath='{.spec.replicas}')
    } || {
	RC=$(oc get deployment $deployment  -n $namespace -o=jsonpath='{.spec.replicas}')
    }
    echo "[INFO] $(date) Replica count for deployment, $deployment before scaling down is $RC"
    #jsonstr="${deployment}-RC":$RC
    jsonstr=$jsonstr\"${deployment}-RC\":$RC,    
done

rm -f $WORKDIR/restore/cassandra/aiops-topology-rc-data.json
echo {$jsonstr}  > $WORKDIR/restore/cassandra/aiops-topology-rc-data.json
sed -zri 's/,([^,]*$)/\1/' $WORKDIR/restore/cassandra/aiops-topology-rc-data.json


#Scaling down the metric and topology pod before Cassandra backup
echo "[INFO] $(date) Scaling down the metric and topology deployment before Cassandra backup"
for deployment in $deploymentList; do

   {
    #TRY
       oc scale deployment $deployment -n $namespace --replicas=0 
   } || {
       oc scale deployment $deployment -n $namespace --replicas=0
   }
done
