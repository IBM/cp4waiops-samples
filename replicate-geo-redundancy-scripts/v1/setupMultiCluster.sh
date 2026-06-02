#!/usr/bin/env bash
# Fail on error
set -euo pipefail

set -a
source config.env
set +a

# Register the Primary cluster for multi-cluster support
aiopsctl multi-cluster add $PRIMARY_CLUSTER_NAME $PRIMARY_CLUSTER_API_ENDPOINT --token=$PRIMARY_CLUSTER_TOKEN --namespace $PRIMARY_CLUSTER_NAMESPACE --insecure-skip-tls-verify --role Primary 

aiopsctl multi-cluster add $BACKUP_CLUSTER_NAME $BACKUP_CLUSTER_API_ENDPOINT --token=$BACKUP_CLUSTER_TOKEN --namespace $BACKUP_CLUSTER_NAMESPACE --insecure-skip-tls-verify --role Backup 

aiopsctl multi-cluster link $PRIMARY_CLUSTER_NAME $BACKUP_CLUSTER_NAME --lifetime $TOKEN_LIFETIME_HOURS