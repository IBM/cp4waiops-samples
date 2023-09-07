#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#
source $WORKDIR/common/check-aiops-version.sh

echo "[INFO] $(date) ############## Restore process started ##############"
BASEDIR=$(dirname "$0")
echo $BASEDIR

cd $BASEDIR

CURRENT=$(pwd)
echo $CURRENT

nsRestore() {
     $CURRENT/other-resources/restore-namespace.sh
}

csRestore() {
     $CURRENT/common-services/cs-restore.sh
}

metastoreRestore() {
     $CURRENT/metastore/metastore-restore.sh
}

couchdbRestore() {
     $CURRENT/couchdb/couchdb-restore.sh
}

redisRestore() {
     $CURRENT/redis/redis-restore.sh
}

esRestore(){
     $CURRENT/elasticsearch/es-restore.sh
}

cassandraRestore(){
     $CURRENT/cassandra/cassandra-restore.sh
}

minioRestore(){
     $CURRENT/minio/minio-restore.sh
}

postgresRestore(){
     $CURRENT/postgres/edb-postgres-restore.sh
}

connectionCrRestore(){
     $CURRENT/other-resources/connection-cr-restore.sh
}

tunnelCrRestore(){
     $CURRENT/other-resources/tunnel-cr-restore.sh
}

ibmVaultRestore() {
     $CURRENT/vault/ibm-vault-restore.sh
}

camRestore() {
     $CURRENT/cam/cam-restore.sh
}

imRestore() {
     $CURRENT/infrastructure-management/im-restore.sh
}


case "$1" in
-h | --help)
   echo "options:"
   echo "-h, --help                               show brief help"
   echo "-ns, --ns-restore                        option to restore CP4WAIOPS namespaces"
   echo "-cs, --cs-restore                        option to restore IBM Common Services"
   echo "-metastore, --metastore-restore          option to restore Metastore"
   echo "-couchdb, --couchdb-restore              option to restore Couchdb"
   echo "-es, --es-restore                        option to restore ElasticSearch"
   echo "-cassandra, --cassandra-restore          option to restore Cassandra"
   echo "-minio, --minio-restore                  option to restore Minio"
   echo "-postgres, --postgres-restore            option to restore EDB-Postgres"
   echo "-connectioncr, --connectioncr-restore    option to restore Connection CR"
   echo "-tunnelcr, --tunnelcr-restore            option to restore Tunnel CR"
   echo "-vault, --vault-restore                  option to restore IBM Vault"
   echo "-cam, --cam-restore                      option to restore CAM"
   echo "-im, --im-restore                        option to restore Infrastructure Management"
   echo "-ia, --ia-restore                        option to restore Infrastructure Automation"
   echo "-aiops, --aiops-restore                  option to restore all components of CP4WAIOPS"
   exit 0
   ;;
-ns | --ns-restore)
   nsRestore
   ;;
-cs | --cs-restore)
   csRestore
   ;;
-metastore | --metastore-restore)
   metastoreRestore
   ;;
-couchdb | --couchdb-restore)
   couchdbRestore
   ;;
-redis | --redis-restore)
   redisRestore
   ;;
-es | --es-restore)
   esRestore
   ;;
-cassandra | --cassandra-restore)
   cassandraRestore
   ;;
-minio | --minio-restore)
   minioRestore
   ;;
-postgres | --postgres-restore)
   postgresRestore
   ;;
-connectioncr | --connectioncr-restore)
   connectionCrRestore
   ;;
-tunnelcr | --tunnelcr-restore)
   tunnelCrRestore
   ;;
-vault | --vault-restore)
   ibmVaultRestore
   ;;
-cam | --cam-restore)
   camRestore
   ;;
-im | --im-restore)
   imRestore
   ;;
-ia | --ia-restore)
   csRestore
   metastoreRestore
   camRestore
   imRestore
   ;;
-aiops | --aiops-restore)
   echo "[INFO] $(date) Validating AIOPS version with respect to BCDR artefacts version" 
   checkAiopsVersion
   if [ $versionCheckValue -ne 0 ]; then
           exit 1
   fi
   echo "[INFO] $(date) ##### Starting restore for all the CP4WAIOPS components #####"
   csRestore
   metastoreRestore
   couchdbRestore
   redisRestore
   esRestore
   cassandraRestore
   minioRestore
   postgresRestore
   connectionCrRestore
   tunnelCrRestore
   ibmVaultRestore
   ;;
*)
   echo "[WARNING] $(date) #### Run the script with valid option, to get the list of available options run the script with -h option ####"
   break
   ;;
esac
