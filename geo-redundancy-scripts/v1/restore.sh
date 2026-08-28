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
#   - Connections (v1 external API, and connections via rb endpoint using oc exec into aimanager-aio-controller pod)
#   - Filters
#   - Menus
#   - Policies       (via policy-batches endpoint, in configurable chunks with 429 retry)
#   - Runbooks       (via RBA v1 bulk import endpoint)
#   - Actions        (via RBA v1 API; referred to as Tools in the v2 configuration API)
#   - Topology configuration
#   - Training definitions
#   - User preferences  (via PUT /user-preferences/me/keys/{key} — one PUT per preference key)
#   - Views
#
# Resources deliberately excluded from restore:
#   - Alerts / Events / Incidents / Metering (runtime / operational data)
#   - Runbook executions                     (runtime state)
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
    local skipped=0

    local tmp_item
    tmp_item=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_item}'" RETURN

    for i in $(seq 0 $(( item_count - 1 ))); do
        # Strip read-only / server-managed fields that cause 400 on re-POST
        jq ".items[$i] | del(._id, .id, .createdAt, .updatedAt, .created, .updated, .lastModified, .lastUpdated, .revision, .__v)" \
            "${input_file}" > "${tmp_item}"

        # Skip predefined system actions — they exist on every cluster and
        # have no script field, so the API rejects them with 400.
        local action_type
        action_type=$(jq -r '._actionType // empty' "${tmp_item}" 2>/dev/null || true)
        if [[ "$action_type" == "predefined" ]]; then
            local action_name
            action_name=$(jq -r '.name // "unknown"' "${tmp_item}" 2>/dev/null || echo "unknown")
            echo "  Skipping '${action_name}' (predefined system action)"
            skipped=$(( skipped + 1 ))
            continue
        fi

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        local resp_body
        resp_body=$(mktemp)
        HTTP_CODE=$(curl -k -X POST "${CLUSTER_CPD_ENDPOINT}${api_path}" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "@${tmp_item}" \
            --write-out "%{http_code}" \
            --silent \
            --output "${resp_body}")

        if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            local item_name
            item_name=$(jq -r '.name // .algorithmName // .definitionName // .id // "unknown"' "${tmp_item}" 2>/dev/null || echo "unknown")
            echo "  Warning: HTTP ${HTTP_CODE} for item '${item_name}' (index ${i})"
            echo "    Response: $(cat "${resp_body}" 2>/dev/null | head -c 300)"
        fi
        rm -f "${resp_body}"
    done

    echo "  ${success}/${item_count} item(s) restored successfully (${skipped} predefined skipped)"
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

    local tmp_payload
    tmp_payload=$(mktemp)
    # Ensure temp file is cleaned up on exit from this function
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_payload}'" RETURN

    if [[ "$wrap_key" == "__array__" ]]; then
        # Unwrap the stored { "items": [...] } back to a plain array
        jq '.items' "${input_file}" > "${tmp_payload}"
        # Skip if the array is empty — endpoints reject an empty array body
        local arr_len
        arr_len=$(jq 'length' "${tmp_payload}" 2>/dev/null || echo "0")
        if [[ "$arr_len" -eq 0 ]]; then
            echo "Skipping ${label} — 0 items in backup"
            TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
            return 0
        fi
    elif [[ -n "$wrap_key" ]]; then
        # Build e.g. { "policies": [ ... ] } from the items array
        jq "{\"${wrap_key}\": .items}" "${input_file}" > "${tmp_payload}"
    else
        cp "${input_file}" "${tmp_payload}"
    fi

    TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

    HTTP_CODE=$(curl -k -X "${method}" "${CLUSTER_CPD_ENDPOINT}${api_path}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --data "@${tmp_payload}" \
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
            --data "@${tmp_payload}" \
            --silent
        echo ""
        exit 1
    fi
}

# ============================================
# Helper: restore internal connections (v3) from connections-internal.json
# Each item is POSTed individually to POST /v3/connections via oc exec.
# restore_exec_connections <pod_name> <namespace> <backup_filename>
# ============================================
restore_exec_connections() {
    local pod_name="$1"
    local namespace="$2"
    local backup_filename="$3"
    local input_file="${BACKUP_DIR}/${backup_filename}"
    local label="Internal Connections (v3)"

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
        echo "  [dry-run] Would POST ${item_count} item(s) via oc exec to https://localhost:9443/v3/connections"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0

    for i in $(seq 0 $(( item_count - 1 ))); do
        local item_json item_name
        item_json=$(jq ".items[$i]" "${input_file}")
        item_name=$(echo "${item_json}" | jq -r '.connection_config.display_name // .name // "unknown"' 2>/dev/null || echo "unknown")

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        # Copy JSON into the pod and curl from the in-pod file — avoids all
        # shell quoting issues that occur when piping through oc exec stdin.
        local tmp_json pod_tmp
        tmp_json=$(mktemp)
        pod_tmp="/tmp/v3_conn_restore_${i}.json"
        echo "${item_json}" > "${tmp_json}"
        oc -n "${namespace}" cp "${tmp_json}" "${pod_name}:${pod_tmp}" 2>/dev/null || true
        rm -f "${tmp_json}"

        local raw_output
        raw_output=$(oc -n "${namespace}" exec "${pod_name}" -- \
            curl -sk -X POST "https://localhost:9443/v3/connections" \
            -H "x-tenantid: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            -H "authorization: Bearer ${JWT_TOKEN}" \
            -H "Content-Type: application/json" \
            -H "Cache-Control: no-cache, no-store" \
            --data "@${pod_tmp}" \
            -w "HTTPCODE%{http_code}" 2>/dev/null || true)

        oc -n "${namespace}" exec "${pod_name}" -- rm -f "${pod_tmp}" 2>/dev/null || true

        local HTTP_CODE
        HTTP_CODE="${raw_output##*HTTPCODE}"
        HTTP_CODE="${HTTP_CODE//[^0-9]/}"
        local resp_body="${raw_output%%HTTPCODE*}"

        if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            echo "  Warning: HTTP ${HTTP_CODE} for connection '${item_name}' (index ${i})"
            echo "    Response: $(echo "${resp_body}" | head -c 300)"
        fi
    done

    echo "  ${success}/${item_count} item(s) restored successfully"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} item(s) failed to restore"
    fi
}

# ============================================
# Helper: restore runbooks connections from connections-runbooks.json
# Each item is POSTed to a type-specific path via oc exec:
#   SCRIPT → POST /v1/runbooks/connections/ssh
#   AWX    → POST /v1/runbooks/connections/ansible
# Note: private keys are not backed up; users must re-add them after restore.
# restore_exec_runbooks_connections <pod_name> <namespace> <backup_filename>
# ============================================
restore_exec_runbooks_connections() {
    local pod_name="$1"
    local namespace="$2"
    local backup_filename="$3"
    local input_file="${BACKUP_DIR}/${backup_filename}"
    local label="Internal Connections (runbooks)"

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
    echo "  Note: private keys are not restored — re-add them manually after restore"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would POST ${item_count} item(s) via oc exec to /v1/runbooks/connections/{type}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0

    for i in $(seq 0 $(( item_count - 1 ))); do
        local item_json conn_type path_segment
        item_json=$(jq ".items[$i]" "${input_file}")
        conn_type=$(echo "${item_json}" | jq -r '.type // empty')

        # Map connection type to path segment
        case "${conn_type}" in
            SCRIPT) path_segment="ssh" ;;
            AWX)    path_segment="ansible" ;;
            *)
                echo "  Warning: Unknown runbooks connection type '${conn_type}' at index ${i} — skipping"
                failed=$(( failed + 1 ))
                continue
                ;;
        esac

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        # Write JSON to a host temp file, copy it into the pod, curl from there,
        # then remove it — avoids all shell quoting issues with oc exec stdin pipes.
        local tmp_json pod_tmp
        tmp_json=$(mktemp)
        pod_tmp="/tmp/rba_conn_restore_${i}.json"
        echo "${item_json}" > "${tmp_json}"
        oc -n "${namespace}" cp "${tmp_json}" "${pod_name}:${pod_tmp}" 2>/dev/null || true
        rm -f "${tmp_json}"

        local raw_output
        raw_output=$(oc -n "${namespace}" exec "${pod_name}" -- \
            curl -sk -X POST "https://localhost:9443/v1/runbooks/connections/${path_segment}" \
            -H "x-tenantid: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            -H "authorization: Bearer ${JWT_TOKEN}" \
            -H "Content-Type: application/json" \
            -H "Cache-Control: no-cache, no-store" \
            --data "@${pod_tmp}" \
            -w "HTTPCODE%{http_code}" 2>/dev/null || true)

        oc -n "${namespace}" exec "${pod_name}" -- rm -f "${pod_tmp}" 2>/dev/null || true

        local HTTP_CODE
        HTTP_CODE="${raw_output##*HTTPCODE}"
        HTTP_CODE="${HTTP_CODE//[^0-9]/}"
        local resp_body="${raw_output%%HTTPCODE*}"

        # Always verify via GET — the POST may return a spurious non-2xx from a
        # gateway even when the connection was created successfully. The GET is
        # the authoritative source of truth.
        local verify_output verify_code
        verify_output=$(oc -n "${namespace}" exec "${pod_name}" -- \
            curl -sk -X GET "https://localhost:9443/v1/runbooks/connections" \
            -H "x-tenantid: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            -H "authorization: Bearer ${JWT_TOKEN}" \
            -H "Cache-Control: no-cache, no-store" \
            -w "HTTPCODE%{http_code}" 2>/dev/null || true)
        verify_code="${verify_output##*HTTPCODE}"
        verify_code="${verify_code//[^0-9]/}"
        local verify_body="${verify_output%%HTTPCODE*}"
        local found
        found=$(echo "${verify_body}" | jq --arg t "${conn_type}" '[.[] | select(.type == $t)] | length' 2>/dev/null || echo "0")

        if [[ "${verify_code}" -ge 200 && "${verify_code}" -lt 300 && "${found}" -gt 0 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            echo "  Warning: Failed to restore connection type '${conn_type}' (index ${i})"
            if [[ -z "${verify_code}" || "${verify_code}" -lt 200 || "${verify_code}" -ge 300 ]]; then
                echo "    Verification GET failed (HTTP ${verify_code}): $(echo "${verify_body}" | head -c 300)"
            else
                echo "    Connection not found after POST — it may already exist or the POST was rejected"
                echo "    POST HTTP ${HTTP_CODE}: $(echo "${resp_body}" | head -c 300)"
            fi
        fi
    done

    echo "  ${success}/${item_count} item(s) restored successfully"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} item(s) failed to restore"
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

        HTTP_CODE=$(echo "${payload}" | curl -k -X POST \
            "${CLUSTER_CPD_ENDPOINT}/aiops/api/v1/configuration/connection-types/${conn_type}/connections" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data @- \
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
# Helper: restore Algorithms
#
# The POST /algorithms endpoint re-registers algorithms.  Live API testing shows:
#   - Only runtimeName "SPARK" or "LUIGI" is accepted by the endpoint
#   - Required fields: algorithmName, algorithmDescription, isEnabled,
#                      runtimeName, configBase64, configType
#   - The backup stores the config as manifestBase64 (YAML) — map it to
#     configBase64 and set configType="YAML"
#
# Algorithms with runtimeName K8s / GENAI / LADGS are system-managed components;
# the API provides no update path for them.  They are skipped with a notice.
# ============================================
restore_algorithms() {
    local input_file="${BACKUP_DIR}/algorithms.json"
    local label="Algorithms"

    if [[ ! -f "${input_file}" ]]; then
        echo "Skipping ${label} — file not found: algorithms.json"
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
        local spark_count
        spark_count=$(jq '[.items[] | select(.runtimeName == "SPARK" or .runtimeName == "LUIGI")] | length' "${input_file}")
        echo "  [dry-run] Would POST ${spark_count} SPARK/LUIGI item(s) to /aiops/api/v2/configuration/algorithms"
        echo "  [dry-run] Would skip $(( item_count - spark_count )) system-managed item(s) (K8s/GENAI/LADGS/…)"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0
    local skipped=0

    local tmp_item resp_body
    tmp_item=$(mktemp)
    resp_body=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_item}' '${resp_body}'" RETURN

    for i in $(seq 0 $(( item_count - 1 ))); do
        local alg_name runtime
        alg_name=$(jq -r ".items[$i].algorithmName // empty" "${input_file}")
        runtime=$(jq -r ".items[$i].runtimeName // empty" "${input_file}")

        if [[ -z "$alg_name" ]]; then
            echo "  Warning: item at index ${i} has no algorithmName — skipping"
            skipped=$(( skipped + 1 ))
            continue
        fi

        # Only SPARK and LUIGI can be POSTed; other runtimes are system-managed
        if [[ "$runtime" != "SPARK" && "$runtime" != "LUIGI" ]]; then
            echo "  Skipping '${alg_name}' (runtimeName=${runtime} — system-managed, no API update path)"
            skipped=$(( skipped + 1 ))
            continue
        fi

        # Map backup fields to the POST envelope.
        # manifestBase64 contains YAML; send as configBase64 with configType=YAML.
        jq ".items[$i] | {
              algorithmName:        .algorithmName,
              algorithmDescription: .algorithmDescription,
              isEnabled:            .isEnabled,
              runtimeName:          .runtimeName,
              configBase64:         .manifestBase64,
              configType:           \"YAML\"
            }" "${input_file}" > "${tmp_item}"

        TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

        HTTP_CODE=$(curl -k -X POST \
            "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/algorithms" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "@${tmp_item}" \
            --write-out "%{http_code}" \
            --silent \
            --output "${resp_body}")

        if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
            success=$(( success + 1 ))
            TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
        else
            failed=$(( failed + 1 ))
            echo "  Warning: HTTP ${HTTP_CODE} for item '${alg_name}' (index ${i})"
            echo "    Response: $(jq -c '.' "${resp_body}" 2>/dev/null | head -c 300)"
        fi
    done

    echo "  ${success}/${item_count} item(s) restored successfully (${skipped} system-managed skipped)"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} item(s) failed to restore"
    fi
}

# ============================================
# Restore each resource type
# ============================================

restore_algorithms

restore_connections "connections.json"

# Internal connections are only reachable via localhost:9443 inside the controller
# pod. We locate the pod once and reuse it for both endpoints.
AIOPS_CONTROLLER_POD=$(oc get pods -n "${CLUSTER_NAMESPACE}" --no-headers \
    -o custom-columns=":metadata.name" | grep "aimanager-aio-controller" | head -1)

if [[ -z "$AIOPS_CONTROLLER_POD" ]]; then
    echo "Warning: No aimanager-aio-controller pod found in namespace ${CLUSTER_NAMESPACE} — skipping internal connections restore"
    TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 2 ))
else
    echo "Using pod for internal connections restore: ${AIOPS_CONTROLLER_POD}"

    restore_exec_connections \
        "${AIOPS_CONTROLLER_POD}" \
        "${CLUSTER_NAMESPACE}" \
        "connections-internal.json"

    restore_exec_runbooks_connections \
        "${AIOPS_CONTROLLER_POD}" \
        "${CLUSTER_NAMESPACE}" \
        "connections-runbooks.json"
fi

restore_items \
    "Filters" \
    "/aiops/api/v2/configuration/filters" \
    "filters.json"

restore_items \
    "Menus" \
    "/aiops/api/v2/configuration/menus" \
    "menus.json"

# ============================================
# Helper: POST a slice of policies [slice_start, slice_end] (inclusive, 0-based)
# from POLICY_FILE to the policy-batches endpoint.
#
# Handles two transient error cases automatically:
#   HTTP 429 — rate limited: sleep for retryAfter ms (from response body) then
#               retry the same slice once.
#   HTTP 413 — payload too large: split the slice in half and recurse into each
#               half so that oversized individual policies are still sent 1-at-a-time.
#
# Updates the caller's policy_success / policy_failed counters via nameref.
# Usage: post_policy_slice <slice_start> <slice_end>
# ============================================
post_policy_slice() {
    local slice_start="$1"
    local slice_end="$2"
    local chunk_size=$(( slice_end - slice_start + 1 ))

    local p_tmp p_resp
    p_tmp=$(mktemp)
    p_resp=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '${p_tmp}' '${p_resp}'" RETURN

    jq --argjson s "$slice_start" --argjson e "$slice_end" \
        '{"policies": [.items[$s:($e+1)][] | del(.id, .status, .hash, .revision)]}' \
        "${POLICY_FILE}" > "${p_tmp}"

    local http_code
    http_code=$(curl -k -X POST \
        "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/policy-batches" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --data "@${p_tmp}" \
        --write-out "%{http_code}" \
        --silent \
        --output "${p_resp}")

    if [[ "${http_code}" -eq 429 ]]; then
        # Honour the retryAfter delay (milliseconds) from the response body,
        # then retry this same slice once before giving up.
        local retry_after_ms retry_after_s
        retry_after_ms=$(jq -r '.retryAfter // 0' "${p_resp}" 2>/dev/null || echo "0")
        retry_after_s=$(( (retry_after_ms + 999) / 1000 ))
        if [[ $retry_after_s -lt 1 ]]; then retry_after_s=1; fi
        echo "  Rate limited (HTTP 429) at index ${slice_start}–${slice_end}; waiting ${retry_after_s}s before retry..."
        sleep "${retry_after_s}"

        http_code=$(curl -k -X POST \
            "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/policy-batches" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --data "@${p_tmp}" \
            --write-out "%{http_code}" \
            --silent \
            --output "${p_resp}")
    fi

    if [[ "${http_code}" -eq 413 ]]; then
        # Payload too large — split in half and recurse.
        # If the slice is already a single item there is nothing to split; give up.
        if [[ $chunk_size -eq 1 ]]; then
            policy_failed=$(( policy_failed + 1 ))
            local policy_name
            policy_name=$(jq -r '.policies[0].name // .policies[0].id // "unknown"' "${p_tmp}" 2>/dev/null || echo "unknown")
            echo "  Warning: HTTP 413 for single policy '${policy_name}' (index ${slice_start}) — policy too large to send"
            echo "    Response: $(cat "${p_resp}" 2>/dev/null | head -c 300)"
            return
        fi
        local mid=$(( (slice_start + slice_end) / 2 ))
        echo "  Payload too large (HTTP 413) at index ${slice_start}–${slice_end}; splitting into [${slice_start}–${mid}] and [$(( mid + 1 ))–${slice_end}]..."
        post_policy_slice "${slice_start}" "${mid}"
        post_policy_slice "$(( mid + 1 ))" "${slice_end}"
        return
    fi

    if [[ "${http_code}" -ge 200 && "${http_code}" -lt 300 ]]; then
        policy_success=$(( policy_success + chunk_size ))
        TOTAL_SUCCESS=$(( TOTAL_SUCCESS + chunk_size ))
    else
        policy_failed=$(( policy_failed + chunk_size ))
        echo "  Warning: HTTP ${http_code} for policies at index ${slice_start}–${slice_end}"
        echo "    Response: $(cat "${p_resp}" 2>/dev/null | head -c 300)"
    fi
}

# Policies: POST in chunks of POLICY_BATCH_SIZE to the policy-batches endpoint,
# using up to POLICY_PARALLEL_JOBS concurrent background jobs for speed.
# 413 (payload too large) is handled by splitting the chunk in half recursively.
# 429 (rate limited) is handled by sleeping retryAfter ms then retrying once.
POLICY_FILE="${BACKUP_DIR}/policies.json"
POLICY_BATCH_SIZE=20
POLICY_PARALLEL_JOBS=4

if [[ ! -f "${POLICY_FILE}" ]]; then
    echo "Skipping Policies — file not found: policies.json"
    TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
else
    policy_count=$(jq '.items | length' "${POLICY_FILE}" 2>/dev/null || echo "0")

    if [[ "$policy_count" -eq 0 ]]; then
        echo "Skipping Policies — 0 items in backup"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
    else
        batch_count=$(( (policy_count + POLICY_BATCH_SIZE - 1) / POLICY_BATCH_SIZE ))
        echo "Restoring Policies (${policy_count} item(s), batch size ${POLICY_BATCH_SIZE}, parallel jobs ${POLICY_PARALLEL_JOBS})..."

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "  [dry-run] Would POST ${policy_count} policy/policies in ${batch_count} batch(es) to /aiops/api/v2/configuration/policy-batches"
            TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        else
            policy_success=0
            policy_failed=0

            TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + policy_count ))

            # Temporary directory for per-batch result files written by background jobs.
            # Each job writes "<success_count> <failed_count>" plus any warning lines.
            policy_tmp_dir=$(mktemp -d)
            # shellcheck disable=SC2064
            trap "rm -rf '${policy_tmp_dir}'" EXIT

            # Array of in-flight PIDs and their associated result files, used as a
            # fixed-width semaphore: when POLICY_PARALLEL_JOBS slots are full we wait
            # for the oldest job before launching the next one.
            declare -a _job_pids=()
            declare -a _job_result_files=()

            # ----------------------------------------
            # _wait_for_oldest_job
            # Wait for the PID at index 0 of _job_pids, then remove it (and its
            # corresponding result-file entry) from both arrays.
            # ----------------------------------------
            _wait_for_oldest_job() {
                wait "${_job_pids[0]}" 2>/dev/null || true
                unset '_job_pids[0]'
                unset '_job_result_files[0]'
                _job_pids=( "${_job_pids[@]+"${_job_pids[@]}"}" )
                _job_result_files=( "${_job_result_files[@]+"${_job_result_files[@]}"}" )
            }

            batch_index=0
            start=0
            while [[ $start -lt $policy_count ]]; do
                end=$(( start + POLICY_BATCH_SIZE - 1 ))
                if [[ $end -ge $policy_count ]]; then
                    end=$(( policy_count - 1 ))
                fi

                # If the parallel window is full, drain the oldest job first.
                if [[ ${#_job_pids[@]} -ge $POLICY_PARALLEL_JOBS ]]; then
                    _wait_for_oldest_job
                fi

                # Launch this batch slice in a background subshell.
                # The subshell inherits post_policy_slice, POLICY_FILE,
                # CLUSTER_CPD_ENDPOINT, JWT_TOKEN, and all globals it needs.
                result_file="${policy_tmp_dir}/batch_${batch_index}.result"
                (
                    # Subshell-local counters; post_policy_slice updates them.
                    policy_success=0
                    policy_failed=0
                    post_policy_slice "${start}" "${end}"
                    echo "${policy_success} ${policy_failed}" > "${result_file}"
                ) &
                _job_pids+=( $! )
                _job_result_files+=( "${result_file}" )

                batch_index=$(( batch_index + 1 ))
                start=$(( end + 1 ))
            done

            # Wait for all remaining in-flight jobs.
            for pid in "${_job_pids[@]+"${_job_pids[@]}"}"; do
                wait "${pid}" 2>/dev/null || true
            done

            # Aggregate results from every batch result file.
            for result_file in "${policy_tmp_dir}"/batch_*.result; do
                [[ -f "$result_file" ]] || continue
                read -r batch_ok batch_err < "${result_file}"
                policy_success=$(( policy_success + batch_ok ))
                policy_failed=$(( policy_failed  + batch_err ))
            done

            rm -rf "${policy_tmp_dir}"

            echo "  ${policy_success}/${policy_count} item(s) restored successfully"
            if [[ $policy_failed -gt 0 ]]; then
                echo "  Warning: ${policy_failed} item(s) failed to restore"
            fi
        fi
    fi
fi

# Runbooks: restore via the RBA v1 bulk import endpoint.
# The backup file holds { "items": [...] } where each item is an exportFormat runbook.
# POST /api/v1/rba/runbooks/import accepts a plain array.
restore_file \
    "Runbooks" \
    "POST" \
    "/aiops/api/story-manager/rba/v1/runbooks/import" \
    "runbooks.json" \
    "__array__"

# Actions (RBA terminology for Tools): restore via the RBA v1 API, one per POST.
restore_items \
    "Actions" \
    "/aiops/api/story-manager/rba/v1/actions" \
    "actions.json"

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

# ============================================
# User preferences: one PUT per key per user item in the backup.
# Endpoint: PUT /aiops/api/v2/configuration/user-preferences/{user-id}/keys/{key}
# Body:     { "value": { "<key>": <value> } }
# This is a server-side upsert — the user-id and key are created if absent.
# The backup file stores { "items": [...] } where each item is a flat object of
# preference key/value pairs (e.g. { "fontSize": 16, "useRowColoring": true }).
# The GET response from the downstream user-config service does not include a
# userId field, so we use "me" as the user-id for all items (REST convention
# for the token-bearing authenticated user).
# ============================================
restore_user_preferences() {
    local input_file="${BACKUP_DIR}/user-preferences.json"
    local label="User preferences"

    if [[ ! -f "${input_file}" ]]; then
        echo "Skipping ${label} — file not found: user-preferences.json"
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

    # Count total keys across all items for the progress line
    local total_keys
    total_keys=$(jq '[.items[] | keys | length] | add // 0' "${input_file}" 2>/dev/null || echo "0")

    echo "Restoring ${label} (${item_count} item(s), ${total_keys} key(s))..."

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  [dry-run] Would PUT ${total_keys} key(s) to /aiops/api/v2/configuration/user-preferences/me/keys/{key}"
        TOTAL_SKIPPED=$(( TOTAL_SKIPPED + 1 ))
        return 0
    fi

    local success=0
    local failed=0

    local tmp_payload
    tmp_payload=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '${tmp_payload}'" RETURN

    for i in $(seq 0 $(( item_count - 1 ))); do
        local keys
        keys=$(jq -r ".items[$i] | keys[]" "${input_file}" 2>/dev/null || true)

        while IFS= read -r key; do
            # Build body: { "value": { "<key>": <value> } }
            jq --arg k "$key" --argjson idx "$i" \
                '{"value": {($k): .items[$idx][$k]}}' \
                "${input_file}" > "${tmp_payload}"

            TOTAL_ATTEMPTED=$(( TOTAL_ATTEMPTED + 1 ))

            local resp_body
            resp_body=$(mktemp)
            HTTP_CODE=$(curl -k -X PUT \
                "${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/user-preferences/me/keys/${key}" \
                --header "Content-Type: application/json" \
                --header "Authorization: Bearer ${JWT_TOKEN}" \
                --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
                --data "@${tmp_payload}" \
                --write-out "%{http_code}" \
                --silent \
                --output "${resp_body}")

            if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
                success=$(( success + 1 ))
                TOTAL_SUCCESS=$(( TOTAL_SUCCESS + 1 ))
            else
                failed=$(( failed + 1 ))
                echo "  Warning: HTTP ${HTTP_CODE} for key '${key}' (item index ${i})"
                echo "    Response: $(cat "${resp_body}" 2>/dev/null | head -c 300)"
            fi
            rm -f "${resp_body}"
        done <<< "$keys"
    done

    echo "  ${success}/${total_keys} key(s) restored successfully"
    if [[ $failed -gt 0 ]]; then
        echo "  Warning: ${failed} key(s) failed to restore"
    fi
}

restore_user_preferences

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
