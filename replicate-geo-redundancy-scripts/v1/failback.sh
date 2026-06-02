#!/usr/bin/env bash
# Fail on error
set -euo pipefail

set -a
source config.env
set +a

aiopsctl multi-cluster promote $PRIMARY_CLUSTER_NAME --namespace $PRIMARY_CLUSTER_NAMESPACE --insecure-skip-tls-verify