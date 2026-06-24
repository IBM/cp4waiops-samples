#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
# 
#
#
# Exports topology configurations from a specified cluster

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
    echo "Export topology configuration from the specified cluster."
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
echo "Exporting topology from ${CLUSTER_DISPLAY} cluster..."
login_and_get_token "$SOURCE_CLUSTER"

# ============================================
# Export Topology Configuration
# ============================================
OUTPUT_FILE="topology-export.json"
OUTPUT_FILE_TMP="${OUTPUT_FILE}.tmp"
echo "Exporting topology configuration to ${OUTPUT_FILE}..."

curl -k -X GET "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/backup" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer ${JWT_TOKEN}" \
  --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
  --output "${OUTPUT_FILE_TMP}" \
  --silent \
  --show-error

# Check if export was successful
if [ $? -eq 0 ] && [ -f "${OUTPUT_FILE_TMP}" ]; then
  # Prettify the JSON output
  echo "Formatting JSON..."
  if jq '.' "${OUTPUT_FILE_TMP}" > "${OUTPUT_FILE}" 2>/dev/null; then
    rm -f "${OUTPUT_FILE_TMP}"
    FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null)
    echo "Topology configuration exported successfully from ${SOURCE_CLUSTER} cluster!"
    echo "Output file: ${OUTPUT_FILE}"
    echo "File size: ${FILE_SIZE} bytes"
  else
    # If jq fails, just use the original file
    echo "Warning: Could not prettify JSON, using raw format"
    mv "${OUTPUT_FILE_TMP}" "${OUTPUT_FILE}"
    FILE_SIZE=$(stat -f%z "${OUTPUT_FILE}" 2>/dev/null || stat -c%s "${OUTPUT_FILE}" 2>/dev/null)
    echo "Topology configuration exported successfully from ${SOURCE_CLUSTER} cluster!"
    echo "Output file: ${OUTPUT_FILE}"
    echo "File size: ${FILE_SIZE} bytes"
  fi
else
  echo "Error: Failed to export topology configuration"
  rm -f "${OUTPUT_FILE_TMP}"
  exit 1
fi