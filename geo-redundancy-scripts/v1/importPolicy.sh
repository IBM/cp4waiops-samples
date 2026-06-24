#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
# 
#
#
# Imports policies from a specified cluster

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
    echo "Import policies to the specified cluster."
    echo ""
    echo "Options:"
    echo "  --cluster CLUSTER    Specify cluster: backup (default) or primary"
    echo "  --config FILE        Path to config file (default: ./geo_config.env)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                      # Import to backup cluster"
    echo "  $0 --cluster primary                    # Import to primary cluster"
    echo "  $0 --config /path/to/config.env --cluster primary  # Use custom config"
    exit 0
}

# ============================================
# Parse command line arguments
# ============================================
parse_result=0
parse_arguments "backup" "$@" || parse_result=$?

if [[ $parse_result -eq 1 ]]; then
    show_usage
elif [[ $parse_result -eq 2 ]]; then
    exit 1
fi

TARGET_CLUSTER="$SELECTED_CLUSTER"

# ============================================
# Load configuration and login
# ============================================
load_geo_config

# Convert to uppercase for display (portable way)
CLUSTER_DISPLAY=$(echo "$TARGET_CLUSTER" | tr '[:lower:]' '[:upper:]')
echo "Importing policies to ${CLUSTER_DISPLAY} cluster..."
login_and_get_token "$TARGET_CLUSTER"

# ============================================
# Import policies
# ============================================
../../replicate-policies-scripts/v1/import_policies.py \
  --archive prod-policies.tar.gz \
  --target-url "$CLUSTER_CPD_ENDPOINT" \
  --target-token "$JWT_TOKEN" \
  --timeout 180

echo "Policies imported successfully to ${TARGET_CLUSTER} cluster!"

