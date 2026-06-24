#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
# 
#
# 
# Exports policies from a specified cluster

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
    echo "Export policies from the specified cluster."
    echo ""
    echo "Options:"
    echo "  --cluster CLUSTER    Specify cluster: primary (default) or backup"
    echo "  --config FILE        Path to config file (default: ./geo_config.env)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                      # Export from primary cluster"
    echo "  $0 --cluster backup                     # Export from backup cluster"
    echo "  $0 --config /path/to/config.env --cluster backup  # Use custom config"
    exit 0
}

# ============================================
# Parse command line arguments
# ============================================
parse_result=0
parse_arguments "primary" "$@" || parse_result=$?

if [[ $parse_result -eq 1 ]]; then
    show_usage
elif [[ $parse_result -eq 2 ]]; then
    exit 1
fi

SOURCE_CLUSTER="$SELECTED_CLUSTER"

# ============================================
# Load configuration and login
# ============================================
load_geo_config

# Convert to uppercase for display (portable way)
CLUSTER_DISPLAY=$(echo "$SOURCE_CLUSTER" | tr '[:lower:]' '[:upper:]')
echo "Exporting policies from ${CLUSTER_DISPLAY} cluster..."
login_and_get_token "$SOURCE_CLUSTER"

# ============================================
# Export policies
# ============================================
../../replicate-policies-scripts/v1/export_policies.py \
  --source-url "$CLUSTER_CPD_ENDPOINT" \
  --source-token "$JWT_TOKEN" \
  --timeout 180 \
  --output prod-policies.tar.gz

echo "Policies exported successfully from ${SOURCE_CLUSTER} cluster!"