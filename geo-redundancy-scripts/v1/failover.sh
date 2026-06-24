#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
#
#
# Sets the Backup cluster as Active and the Primary cluster as Standby

# Fail on error
set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "${SCRIPT_DIR}/common_functions.sh"

# ============================================
# Show usage
# ============================================
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Promote the backup cluster to active (failover operation)."
    echo "This sets the Backup cluster as Active and the Primary cluster as Standby."
    echo ""
    echo "Options:"
    echo "  --config FILE    Path to config file (default: ./geo_config.env)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                              # Use default config"
    echo "  $0 --config /path/to/config.env # Use custom config"
    exit 0
}

# ============================================
# Parse command line arguments
# ============================================
CONFIG_FILE_PATH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        --config)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --config requires a file path"
                exit 1
            fi
            CONFIG_FILE_PATH="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_usage
            ;;
    esac
done

# ============================================
# Load configuration
# ============================================
load_geo_config

echo "Performing failover operation..."
echo "Promoting backup cluster ($BACKUP_CLUSTER_NAME) to active..."

aiopsctl multi-cluster promote $BACKUP_CLUSTER_NAME --namespace $BACKUP_CLUSTER_NAMESPACE --insecure-skip-tls-verify

echo "Failover completed successfully!"
echo "Backup cluster is now active."