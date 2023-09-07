#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

source cassandra-utils.sh

pbkc() {
 ## Parallel Backup of Kubernetes Cassandra
 DATE=$( date +"%F-%H-%M-%S" )
 LOGFILEBASE=/tmp/clusteredCassandraBackup-${DATE}-
 declare -A PIDWAIT
 declare -A LOG

 ## get the current list of cassandra pods.
 podlist=$( oc get pods -n $namespace --field-selector=status.phase=Running  --no-headers=true --output=custom-columns=NAME:.metadata.name | grep aiops-topology-cassandra-[0-9] )
 for pod in ${podlist}; do
    LOG[$pod]=${LOGFILEBASE}${pod}.log
    echo -e "BACKING UP CASSANDRA IN POD ${pod} (logged to ${LOG[$pod]})"
    oc exec ${pod} -n $namespace -- bash -c "CASSANDRA_USER=\$(cat \$CASSANDRA_AUTH_USERNAME_FILE); CASSANDRA_PASS=\$(cat \$CASSANDRA_AUTH_PASSWORD_FILE); /opt/ibm/backup_scripts/backup_cassandra.sh  -u \${CASSANDRA_USER} -p \${CASSANDRA_PASS} -f" > ${LOG[$pod]} & PIDWAIT[$pod]=$!
 done

 echo -e "${#PIDWAIT[@]} Cassandra backup is in progress ..."

 for pod in ${podlist}; do
    wait ${PIDWAIT[$pod]}
    echo -e "Backup of ${pod} completed, please verify via log file (${LOG[$pod]})"
 done
}

pbkc
