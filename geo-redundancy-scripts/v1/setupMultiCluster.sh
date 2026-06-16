#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
#
#
# Sets up two clusters for multi-cluster support

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
    echo "Set up two clusters for multi-cluster support."
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

echo "Setting up multi-cluster configuration..."
echo "Primary cluster: $PRIMARY_CLUSTER_NAME"
echo "Backup cluster: $BACKUP_CLUSTER_NAME"

# Register the Primary cluster for multi-cluster support
aiopsctl multi-cluster add $PRIMARY_CLUSTER_NAME $PRIMARY_CLUSTER_API_ENDPOINT --token=$PRIMARY_CLUSTER_TOKEN --namespace $PRIMARY_CLUSTER_NAMESPACE --insecure-skip-tls-verify --role Primary

aiopsctl multi-cluster add $BACKUP_CLUSTER_NAME $BACKUP_CLUSTER_API_ENDPOINT --token=$BACKUP_CLUSTER_TOKEN --namespace $BACKUP_CLUSTER_NAMESPACE --insecure-skip-tls-verify --role Backup

aiopsctl multi-cluster link $PRIMARY_CLUSTER_NAME $BACKUP_CLUSTER_NAME --lifetime $TOKEN_LIFETIME_HOURS

echo "Multi-cluster setup completed successfully!"