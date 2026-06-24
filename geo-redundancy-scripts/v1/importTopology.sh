#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
# 
#
#
# Imports topology configurations from a specified cluster

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
    echo "Usage: $0 [OPTIONS] [FILE]"
    echo ""
    echo "Import topology configuration to the specified cluster."
    echo ""
    echo "Options:"
    echo "  --cluster CLUSTER    Specify cluster: backup (default) or primary"
    echo "  --config FILE        Path to config file (default: ./geo_config.env)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Arguments:"
    echo "  FILE                 Path to topology export file (default: topology-export.json)"
    echo ""
    echo "Examples:"
    echo "  $0                                         # Import to backup from topology-export.json"
    echo "  $0 my-topology.json                        # Import to backup from my-topology.json"
    echo "  $0 --cluster primary                       # Import to primary from topology-export.json"
    echo "  $0 --cluster primary my-topology.json      # Import to primary from my-topology.json"
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

# Get input file from remaining arguments or use default
if [[ ${#REMAINING_ARGS[@]} -gt 0 ]]; then
    INPUT_FILE="${REMAINING_ARGS[0]}"
else
    INPUT_FILE="topology-export.json"
fi

# Check if input file exists
if [ ! -f "${INPUT_FILE}" ]; then
  echo "Error: Input file not found: ${INPUT_FILE}"
  echo "Usage: $0 [primary|backup] [topology-export.json]"
  exit 1
fi

echo "Using input file: ${INPUT_FILE}"

# ============================================
# Load configuration and login
# ============================================
load_geo_config

# Convert to uppercase for display (portable way)
CLUSTER_DISPLAY=$(echo "$TARGET_CLUSTER" | tr '[:lower:]' '[:upper:]')
echo "Importing topology to ${CLUSTER_DISPLAY} cluster..."
login_and_get_token "$TARGET_CLUSTER"

# ============================================
# Import Topology Configuration
# ============================================
echo "Importing topology configuration from ${INPUT_FILE}..."

# Read the JSON file content
TOPOLOGY_DATA=$(cat "${INPUT_FILE}")

# Import topology configuration
HTTP_CODE=$(curl -k -X POST "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/restore" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${JWT_TOKEN}" \
  --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
  --data "${TOPOLOGY_DATA}" \
  --write-out "%{http_code}" \
  --silent \
  --output /dev/null)

# Check if import was successful
if [ "${HTTP_CODE}" -ge 200 ] && [ "${HTTP_CODE}" -lt 300 ]; then
  echo "Topology configuration imported successfully to ${TARGET_CLUSTER} cluster!"
  echo "HTTP Status: ${HTTP_CODE}"
else
  echo "Error: Failed to import topology configuration"
  echo "HTTP Status: ${HTTP_CODE}"
  
  # Try to get error details
  echo ""
  echo "Attempting to get error details..."
  curl -k -X POST "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/restore" \
    --header "Content-Type: application/json" \
    --header "Authorization: Bearer ${JWT_TOKEN}" \
    --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
    --data "${TOPOLOGY_DATA}" \
    --silent
  
  exit 1
fi

