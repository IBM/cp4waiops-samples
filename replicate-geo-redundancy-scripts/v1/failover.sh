#!/usr/bin/env bash
# Fail on error
set -euo pipefail

set -a
source geo_config.env
set +a

aiopsctl multi-cluster promote $BACKUP_CLUSTER_NAME --namespace $BACKUP_CLUSTER_NAMESPACE --insecure-skip-tls-verify