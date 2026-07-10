#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
#
#
#
# Restores all restorable configuration data from a backup directory to a cluster.
# The backup directory should have been produced by backup.sh.
#
# Resources restored:
#   - Algorithms
#   - Connections
#   - Filters
#   - Menus
#   - Policies       (via policy-batches endpoint for efficiency)
#   - Runbooks
#   - Tools
#   - Topology configuration
#   - Training definitions
#   - Views
#
# Resources deliberately excluded from restore:
#   - Alerts / Events / Incidents / Metering (runtime / operational data)
#   - Runbook executions                     (runtime state)
#   - User preferences                       (personal per-user data; restored as informational only)
#
# IMPORTANT: This script CREATES resources.  It does not check for duplicates first.
#            Run against an empty or freshly provisioned instance, or pair with
#            manual cleanup of the target before running.

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
    echo "Usage: $0 [OPTIONS] [BACKUP_DIR]"
    echo ""
    echo "Restore all configuration data from a backup directory to the specified cluster."
    echo ""
    echo "Options:"
    echo "  --cluster CLUSTER    Specify cluster: backup (default) or primary"
    echo "  --config FILE        Path to config file (default: ./geo_config.env)"
    echo "  --dry-run            Print what would be sent without making any API calls"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Arguments:"
    echo "  BACKUP_DIR           Path to the backup directory (default: most recent ./backup-* directory)"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Restore to backup cluster from latest backup"
    echo "  $0 ./backup-20250101-120000                  # Restore from specific backup directory"
    echo "  $0 --cluster primary ./backup-20250101-120000"
    echo "  $0 --dry-run ./backup-20250101-120000        # Preview without making changes"
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

# Check REMAINING_ARGS for --dry-run flag and backup directory
DRY_RUN=false
BACKUP_DIR=""
for arg in "${REMAINING_ARGS[@]}"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    elif [[ -z "$BACKUP_DIR" ]]; then
        BACKUP_DIR="$arg"
    fi
done

# If no backup directory was specified, find the most recent one
if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR=$(ls -1d ./backup-* 2>/dev/null | sort | tail -1 || true)
    if [[ -z "$BACKUP_DIR" ]]; then
        echo "Error: No backup directory found. Please specify a backup directory as an argument."
        echo "       Run backup.sh first to create a backup."
        exit 1
    fi
    echo "Using most recent backup directory: ${BACKUP_DIR}"
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Error: Backup directory not found: ${BACKUP_DIR}"
    exit 1
fi

# ============================================
# Load configuration and login
# ============================================
load_geo_config

CLUSTER_DISPLAY=$(echo "$TARGET_CLUSTER" | tr '[:lower:]' '[:upper:]')
echo "Restoring configuration to ${CLUSTER_DISPLAY} cluster..."
echo "Backup directory: ${BACKUP_DIR}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo ""
    echo "*** DRY RUN MODE — no API calls will be made ***"
    echo ""
fi

login_and_get_token "$TARGET_CLUSTER"

# ============================================
# Show backup metadata if present
# ============================================
METADATA_FILE="${BACKUP_DIR}/backup-metadata.json"
if [[ -f "${METADATA_FILE}" ]]; then
    echo ""
    echo "Backup metadata:"
    echo "  Backup timestamp : $(jq -r '.backup_timestamp' "${METADATA_FILE}")"
    echo "  Source cluster   : $(jq -r '.source_cluster' "${METADATA_FILE}")"
    echo "  Cluster endpoint : $(jq -r '.cluster_endpoint' "${METADATA_FILE}")"
    echo ""
fi

# ============================================
# Restore counters
# ============================================
TOTAL_ATTEMPTED=0
TOTAL_SUCCESS=0
TOTAL_SKIPPED=0

# ============================================
# Helper: POST each item in an items array individually
# restore_items <label> <api_path> <backup_filename>
# ============================================
restore_items() {
    local label="$1"
    local api_path="$2"
    local backup_filename="$3"
    local input_file="${BACKUP_DIR}/${backup_filename}"

    if [[ ! -f "${input_file}" ]]; then
        echo "Skipping ${label} — file not found: ${backup_filename}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local item_count
    item_count=$(jq '.items | length' "${input_file}" 2>/dev/null || echo "0")

    if [[ "$item_count" -eq 0 ]]; then
        echo "Skipping ${label} — 0 items in backup"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    echo "Restoring ${label} (${item_count} item(s))..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would POST ${item_count} item(s) to ${api_path}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0

    for i in $(seq 0 $(( item_count - 1 ))); do
        local item_json
        item_json=$(jq ".items[$i]" "${input_file}")

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        HTTP_CODE=$(curl -k -X POST "${CLUSTER_CPD_ENDPOINT}${api_path}" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "${item_json}" \
            --write-out "%{http_code}" \
            --silent \
            --output /dev/null)

        if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            local item_name
            item_name=$(echo "${item_json}" | jq -r '.name // .algorithmName // .definitionName // .id // "unknown"' 2>/dev/null || echo "unknown")
            echo "  Warning: HTTP ${HTTP_CODE} for item '${item_name}' (index ${i})"
        fi
    done

    echo "  ${success}/${item_count} item(s) restored successfully"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} item(s) failed to restore"
    fi
}

# ============================================
# Helper: POST a whole-file payload (e.g. topology restore, policy-batches)
# restore_file <label> <method> <api_path> <backup_filename> [<wrap_key>]
# If wrap_key is provided the file contents are wrapped as: { "<wrap_key>": <items_array> }
# ============================================
restore_file() {
    local label="$1"
    local method="$2"
    local api_path="$3"
    local backup_filename="$4"
    local wrap_key="${5:-}"
    local input_file="${BACKUP_DIR}/${backup_filename}"

    if [[ ! -f "${input_file}" ]]; then
        echo "Skipping ${label} — file not found: ${backup_filename}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    echo "Restoring ${label}..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would ${method} to ${api_path}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local payload
    if [[ -n "$wrap_key" ]]; then
        # Build { "policies": [ ... ] } from the items array
        payload=$(jq "{\"${wrap_key}\": .items}" "${input_file}")
    else
        payload=$(cat "${input_file}")
    fi

    TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

    HTTP_CODE=$(curl -k -X "${method}" "${CLUSTER_CPD_ENDPOINT}${api_path}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --data "${payload}" \
        --write-out "%{http_code}" \
        --silent \
        --output /dev/null)

    if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
        echo "  OK — HTTP ${HTTP_CODE}"
        TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
    else
        echo "  Error: HTTP ${HTTP_CODE} while restoring ${label}"
        # Retry with response body for diagnostics
        echo ""
        echo "  Response body:"
        curl -k -X "${method}" "${CLUSTER_CPD_ENDPOINT}${api_path}" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "${payload}" \
            --silent
        echo ""
        exit 1
    fi
}

# ============================================
# Helper: restore Connections from connections.json
# Connections use the v1 API. Each item in the backup is a ConnectionsListResponseDto
# wrapper object (shape: { code, data: [ConnectionDto] }). Individual ConnectionDto
# objects are nested inside each wrapper's .data[] array.
# The create endpoint is per-type: POST /connection-types/{type}/connections
# restore_connections <backup_filename>
# ============================================
restore_connections() {
    local backup_filename="$1"
    local input_file="${BACKUP_DIR}/${backup_filename}"
    local label="Connections"

    if [[ ! -f "${input_file}" ]]; then
        echo "Skipping ${label} — file not found: ${backup_filename}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    # Flatten all ConnectionDto objects from every wrapper's .data[] array
    local conn_count
    conn_count=$(jq '[.items[].data[]] | length' "${input_file}" 2>/dev/null || echo "0")

    if [[ "$conn_count" -eq 0 ]]; then
        echo "Skipping ${label} — 0 items in backup"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    echo "Restoring ${label} (${conn_count} item(s))..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would POST ${conn_count} connection(s) to /aiops/api/v1/configuration/connection-types/{type}/connections"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0

    for i in $(seq 0 $(( conn_count - 1 ))); do
        local conn_json conn_type conn_name
        conn_json=$(jq "[.items[].data[]] | .[$i]" "${input_file}")
        conn_type=$(echo "${conn_json}" | jq -r '.connectionType // empty')
        conn_name=$(echo "${conn_json}" | jq -r '.name // "unknown"')

        if [[ -z "$conn_type" ]]; then
            echo "  Warning: Connection at index ${i} has no connectionType — skipping"
            failed=$(( failed + 1 ))
            continue
        fi

        # Build CreateConnectionDto: pick only the fields the POST endpoint accepts
        local payload
        payload=$(echo "${conn_json}" | jq '{
            name:             .name,
            displayName:      .displayName,
            deploymentType:   .deploymentType,
            connectorState:   .connectorState,
            connectionConfig: .connectionConfig
        } | with_entries(select(.value != null))')

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        HTTP_CODE=$(curl -k -X POST \
            "${CLUSTER_CPD_ENDPOINT}/aiops/api/v1/configuration/connection-types/${conn_type}/connections" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "${payload}" \
            --write-out "%{http_code}" \
            --silent \
            --output /dev/null)

        if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            echo "  Warning: HTTP ${HTTP_CODE} for connection '${conn_name}' (type: ${conn_type})"
        fi
    done

    echo "  ${success}/${conn_count} connection(s) restored successfully"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} connection(s) failed to restore"
    fi
}

# ============================================
# Restore each resource type
# ============================================

restore_items \
    "Algorithms" \
    "/aiops/api/v2/configuration/algorithms" \
    "algorithms.json"

restore_connections "connections.json"

restore_items \
    "Filters" \
    "/aiops/api/v2/configuration/filters" \
    "filters.json"

restore_items \
    "Menus" \
    "/aiops/api/v2/configuration/menus" \
    "menus.json"

# Policies: use the batch endpoint for efficiency (POST /policy-batches)
restore_file \
    "Policies" \
    "POST" \
    "/aiops/api/v2/configuration/policy-batches" \
    "policies.json" \
    "policies"

restore_items \
    "Runbooks" \
    "/aiops/api/v2/configuration/runbooks" \
    "runbooks.json"

restore_items \
    "Tools" \
    "/aiops/api/v2/configuration/tools" \
    "tools.json"

# Topology: restore via dedicated POST endpoint
restore_file \
    "Topology configuration" \
    "POST" \
    "/aiops/api/v2/configuration/topology/config/restore" \
    "topology.json"

restore_items \
    "Training definitions" \
    "/aiops/api/v2/configuration/training-definitions" \
    "training-definitions.json"

restore_items \
    "Views" \
    "/aiops/api/v2/configuration/views" \
    "views.json"

# ============================================
# Summary
# ============================================
echo ""
echo "============================================"
echo " Restore complete"
echo "============================================"
echo " Target cluster  : ${TARGET_CLUSTER}"
echo " Backup directory: ${BACKUP_DIR}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo " Mode            : DRY RUN (no changes made)"
else
    echo " Attempted       : ${TOTAL_ATTEMPTED}"
    echo " Succeeded       : ${TOTAL_SUCCESS}"
    echo " Skipped         : ${TOTAL_SKIPPED}"
fi
echo ""
