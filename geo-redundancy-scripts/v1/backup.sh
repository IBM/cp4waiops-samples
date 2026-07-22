#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
#
#
#
# Exports all restorable configuration data from a cluster to a local directory.
# The output directory is suitable for committing to a git repository.
#
# Resources exported:
#   - Algorithms
#   - Connections
#   - Filters
#   - Menus
#   - Policies
#   - Runbooks
#   - Actions
#   - Topology configuration
#   - Training definitions
#   - User preferences
#   - Views
#
# Resources deliberately excluded:
#   - Alerts     (runtime operational data)
#   - Events     (runtime operational data)
#   - Incidents  (runtime operational data)
#   - Metering   (billing / observability data)
#   - Runbook executions (runtime state)
#   - Policy IDs / status / timeline (derived / runtime)

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
    echo "Export all restorable configuration data from the specified cluster."
    echo "Output is written to a timestamped directory that can be committed to git."
    echo ""
    echo "Options:"
    echo "  --cluster CLUSTER    Specify cluster: primary (default) or backup"
    echo "  --config FILE        Path to config file (default: ./geo_config.env)"
    echo "  --output DIR         Output directory (default: ./backup-<timestamp>)"
    echo "  --debug              Print the full URL and raw response for every API call"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                           # Backup from primary cluster"
    echo "  $0 --cluster backup                          # Backup from backup cluster"
    echo "  $0 --output ./my-backup                      # Use custom output directory"
    echo "  $0 --debug                                   # Show full API request/response detail"
    echo "  $0 --config /path/to/config.env --cluster backup"
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

# Check REMAINING_ARGS for --output and --debug
OUTPUT_DIR=""
DEBUG=false
remaining_idx=0
while [[ $remaining_idx -lt ${#REMAINING_ARGS[@]} ]]; do
    arg="${REMAINING_ARGS[$remaining_idx]}"
    if [[ "$arg" == "--output" ]]; then
        remaining_idx=$(( remaining_idx + 1 ))
        if [[ $remaining_idx -ge ${#REMAINING_ARGS[@]} ]]; then
            echo "Error: --output requires a directory path"
            exit 1
        fi
        OUTPUT_DIR="${REMAINING_ARGS[$remaining_idx]}"
    elif [[ "$arg" == "--debug" ]]; then
        DEBUG=true
    fi
    remaining_idx=$(( remaining_idx + 1 ))
done

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="./backup-$(date +%Y%m%d-%H%M%S)"
fi

# ============================================
# Load configuration and login
# ============================================
load_geo_config

CLUSTER_DISPLAY=$(echo "$SOURCE_CLUSTER" | tr '[:lower:]' '[:upper:]')
echo "NOTE:"
echo "    If you are using these scripts to replicate data, use aiopsctl’s exchange-token (https://github.com/IBM/aiopsctl) to ensure the connector’s encryption key" 
echo "    gets copied over to the other cluster."
echo "    Both clusters must have the same key to decrypt all the connectors' encrypted data. If the system is clean installed you must have a backup of the"
echo "    aiopsedge-config-encryption-key secret and restore it prior to running the restore script."
echo ""

echo "Backing up configuration from ${CLUSTER_DISPLAY} cluster..."
login_and_get_token "$SOURCE_CLUSTER"

# ============================================
# Prepare output directory
# ============================================
mkdir -p "${OUTPUT_DIR}"
echo "Output directory: ${OUTPUT_DIR}"
echo ""

SKIPPED_RESOURCES=()

# ============================================
# Helper: fetch a resource collection and save to file
# fetch_resource <label> <api_path> <output_filename>
# ============================================
fetch_resource() {
    local label="$1"
    local api_path="$2"
    local output_filename="$3"
    local tmp_file="${OUTPUT_DIR}/${output_filename}.tmp"
    local out_file="${OUTPUT_DIR}/${output_filename}"
    local full_url="${CLUSTER_CPD_ENDPOINT}${api_path}"

    echo "Exporting ${label}..."

    if [[ "$DEBUG" == "true" ]]; then
        echo "  [debug] GET ${full_url}"
    fi

    # Write body to tmp_file; capture HTTP status code on stdout.
    # --verbose goes to stderr (the terminal directly) so it never contaminates
    # the HTTP_CODE capture. || true prevents set -e on non-2xx.
    if [[ "$DEBUG" == "true" ]]; then
        HTTP_CODE=$(curl -k --compressed -X GET "${full_url}" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --output "${tmp_file}" \
            --write-out "%{http_code}" \
            --verbose 2>/dev/tty || true)
    else
        HTTP_CODE=$(curl -k --compressed -X GET "${full_url}" \
            --header "Content-Type: application/json" \
            --header "Authorization: Bearer ${JWT_TOKEN}" \
            --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
            --output "${tmp_file}" \
            --write-out "%{http_code}" \
            --silent 2>/dev/null || true)
    fi

    if [[ "$DEBUG" == "true" && -f "${tmp_file}" ]]; then
        echo "  [debug] Response body:"
        cat "${tmp_file}"
        echo ""
    fi

    # Strip any stray non-digit characters defensively
    HTTP_CODE="${HTTP_CODE//[^0-9]/}"

    if [[ -z "$HTTP_CODE" ]]; then
        echo "  Warning: No HTTP response received for ${label} — skipping"
        echo "  Response body: $(cat "${tmp_file}" 2>/dev/null || true)"
        rm -f "${tmp_file}"
        SKIPPED_RESOURCES+=("${label} (no response)")
        return
    fi

    if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
        if jq '.' "${tmp_file}" > "${out_file}" 2>/dev/null; then
            rm -f "${tmp_file}"
        else
            echo "  Error: API returned non-JSON for ${label} (HTTP ${HTTP_CODE})"
            echo "  Response body (first 500 chars):"
            head -c 500 "${tmp_file}"
            echo ""
            rm -f "${tmp_file}"
            exit 1
        fi
        local item_count
        item_count=$(jq '.items | length' "${out_file}" 2>/dev/null || echo "?")
        echo "  OK — ${item_count} item(s) → ${output_filename}"
    elif [[ "${HTTP_CODE}" -eq 401 || "${HTTP_CODE}" -eq 403 ]]; then
        echo "  Error: HTTP ${HTTP_CODE} (auth failure) while exporting ${label} — aborting"
        echo "  Response body:"
        cat "${tmp_file}" 2>/dev/null || true
        echo ""
        rm -f "${tmp_file}"
        exit 1
    else
        echo "  Warning: HTTP ${HTTP_CODE} while exporting ${label} — skipping"
        echo "  Response body: $(cat "${tmp_file}" 2>/dev/null || true)"
        rm -f "${tmp_file}"
        SKIPPED_RESOURCES+=("${label} (HTTP ${HTTP_CODE})")
    fi
}

# ============================================
# Export each resource type
# ============================================

fetch_resource \
    "Algorithms" \
    "/aiops/api/v2/configuration/algorithms" \
    "algorithms.json"

# Connections use the v1 API (issue-resolution API) and require decryptFields=true
# so that sensitive fields are exported in plaintext and can be re-imported.
# The response shape is { items: [ { code, data: [ConnectionDto] } ] } — the
# fetch_resource helper records .items | length which equals the number of
# ConnectionsListResponseDto wrapper objects (one per connection type queried).
fetch_resource \
    "Connections" \
    "/aiops/api/v1/configuration/connections?decryptFields=true" \
    "connections.json"

fetch_resource \
    "Filters" \
    "/aiops/api/v2/configuration/filters?all=true" \
    "filters.json"

fetch_resource \
    "Menus" \
    "/aiops/api/v2/configuration/menus?all=true" \
    "menus.json"

# Policies: every endpoint caps at 10,000 items per request. Work around this by
# fetching each state (draft/enabled/disabled/archived) in pages using
# paginationFrom offset. States are mutually exclusive so combining them gives
# the complete set. Each page is written to disk and all are merged at the end.
echo "Exporting Policies..."
POLICIES_OUT="${OUTPUT_DIR}/policies.json"
POLICIES_TMP="${OUTPUT_DIR}/policies.json.tmp"
POLICIES_PAGES_DIR="${OUTPUT_DIR}/policies-pages"
POLICIES_BASE_URL="${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/policies"
POLICIES_PAGE_SIZE=5000
policies_skipped=false
policy_page_num=0

mkdir -p "${POLICIES_PAGES_DIR}"

for policy_state in draft enabled disabled archived; do
    state_offset=0
    state_total=0

    while true; do
        state_url="${POLICIES_BASE_URL}?state=${policy_state}&filter%5BpaginationResponseSize%5D=${POLICIES_PAGE_SIZE}&filter%5BpaginationFrom%5D=${state_offset}"

        if [[ "$DEBUG" == "true" ]]; then
            echo "  [debug] GET ${POLICIES_BASE_URL}?state=${policy_state}&filter[paginationResponseSize]=${POLICIES_PAGE_SIZE}&filter[paginationFrom]=${state_offset}"
            P_HTTP_CODE=$(curl -k --compressed --globoff -X GET "${state_url}" \
                --header "Content-Type: application/json" \
                --header "Authorization: Bearer ${JWT_TOKEN}" \
                --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
                --output "${POLICIES_TMP}" \
                --write-out "%{http_code}" \
                --verbose 2>/dev/tty || true)
            echo "  [debug] Response body:"
            cat "${POLICIES_TMP}" 2>/dev/null || true
            echo ""
        else
            P_HTTP_CODE=$(curl -k --compressed --globoff -X GET "${state_url}" \
                --header "Content-Type: application/json" \
                --header "Authorization: Bearer ${JWT_TOKEN}" \
                --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
                --output "${POLICIES_TMP}" \
                --write-out "%{http_code}" \
                --silent 2>/dev/null || true)
        fi

        P_HTTP_CODE="${P_HTTP_CODE//[^0-9]/}"

        if [[ -z "$P_HTTP_CODE" || "${P_HTTP_CODE}" -eq 0 ]]; then
            echo "  Error: No HTTP response received for Policies (state=${policy_state} offset=${state_offset})"
            rm -f "${POLICIES_TMP}"; rm -rf "${POLICIES_PAGES_DIR}"; exit 1
        elif [[ "${P_HTTP_CODE}" -eq 401 || "${P_HTTP_CODE}" -eq 403 ]]; then
            echo "  Error: HTTP ${P_HTTP_CODE} (auth failure) while exporting Policies — aborting"
            cat "${POLICIES_TMP}" 2>/dev/null || true
            rm -f "${POLICIES_TMP}"; rm -rf "${POLICIES_PAGES_DIR}"; exit 1
        elif [[ "${P_HTTP_CODE}" -lt 200 || "${P_HTTP_CODE}" -ge 300 ]]; then
            echo "  Warning: HTTP ${P_HTTP_CODE} while exporting Policies (state=${policy_state} offset=${state_offset}) — skipping"
            rm -f "${POLICIES_TMP}"; rm -rf "${POLICIES_PAGES_DIR}"
            SKIPPED_RESOURCES+=("Policies (HTTP ${P_HTTP_CODE})")
            policies_skipped=true
            break 2
        fi

        if ! jq '.' "${POLICIES_TMP}" > /dev/null 2>&1; then
            echo "  Error: Policies API returned non-JSON for state=${policy_state} offset=${state_offset} (HTTP ${P_HTTP_CODE})"
            head -c 500 "${POLICIES_TMP}"; echo ""
            rm -f "${POLICIES_TMP}"; rm -rf "${POLICIES_PAGES_DIR}"; exit 1
        fi

        page_count=$(jq '.items | length' "${POLICIES_TMP}" 2>/dev/null || echo "0")
        jq '.items' "${POLICIES_TMP}" > "${POLICIES_PAGES_DIR}/page-${policy_page_num}.json"
        rm -f "${POLICIES_TMP}"

        state_total=$(( state_total + page_count ))
        state_offset=$(( state_offset + page_count ))
        policy_page_num=$(( policy_page_num + 1 ))

        if [[ "$page_count" -lt "$POLICIES_PAGE_SIZE" ]]; then
            break  # last page for this state
        fi
    done

    echo "  state=${policy_state}: ${state_total} item(s)"
done

if [[ "$policies_skipped" != "true" ]]; then
    jq -s '{"items": add}' "${POLICIES_PAGES_DIR}"/page-*.json > "${POLICIES_OUT}"
    rm -rf "${POLICIES_PAGES_DIR}"
    total_count=$(jq '.items | length' "${POLICIES_OUT}" 2>/dev/null || echo "?")
    echo "  OK — ${total_count} item(s) → policies.json"
fi

# Runbooks: use the RBA v1 API with exportFormat=true to get importable JSON.
# The response is a plain JSON array; normalise it to { "items": [...] } on save.
echo "Exporting Runbooks..."
RB_TMP="${OUTPUT_DIR}/runbooks.json.tmp"
RB_OUT="${OUTPUT_DIR}/runbooks.json"
RB_URL="${CLUSTER_CPD_ENDPOINT}/aiops/api/story-manager/rba/v1/runbooks?exportFormat=true"

if [[ "$DEBUG" == "true" ]]; then
    echo "  [debug] GET ${RB_URL}"
    RB_HTTP_CODE=$(curl -k --compressed -X GET "${RB_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${RB_TMP}" \
        --write-out "%{http_code}" \
        --verbose 2>/dev/tty || true)
    echo "  [debug] Response body:"
    cat "${RB_TMP}" 2>/dev/null || true
    echo ""
else
    RB_HTTP_CODE=$(curl -k --compressed -X GET "${RB_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${RB_TMP}" \
        --write-out "%{http_code}" \
        --silent 2>/dev/null || true)
fi

RB_HTTP_CODE="${RB_HTTP_CODE//[^0-9]/}"

if [[ "${RB_HTTP_CODE}" -ge 200 && "${RB_HTTP_CODE}" -lt 300 ]]; then
    # Response is a plain array — wrap it as { "items": [...] } for consistency
    if jq '{"items": .}' "${RB_TMP}" > "${RB_OUT}" 2>/dev/null; then
        rm -f "${RB_TMP}"
    else
        echo "  Error: Runbooks API returned non-JSON (HTTP ${RB_HTTP_CODE})"
        echo "  Response body (first 500 chars):"
        head -c 500 "${RB_TMP}"
        echo ""
        rm -f "${RB_TMP}"
        exit 1
    fi
    local_item_count=$(jq '.items | length' "${RB_OUT}" 2>/dev/null || echo "?")
    echo "  OK — ${local_item_count} item(s) → runbooks.json"
elif [[ "${RB_HTTP_CODE}" -eq 401 || "${RB_HTTP_CODE}" -eq 403 ]]; then
    echo "  Error: HTTP ${RB_HTTP_CODE} (auth failure) while exporting Runbooks — aborting"
    echo "  Response body:"
    cat "${RB_TMP}" 2>/dev/null || true
    echo ""
    rm -f "${RB_TMP}"
    exit 1
else
    echo "  Warning: HTTP ${RB_HTTP_CODE} while exporting Runbooks — skipping"
    echo "  Response body: $(cat "${RB_TMP}" 2>/dev/null || true)"
    rm -f "${RB_TMP}"
    SKIPPED_RESOURCES+=("Runbooks (HTTP ${RB_HTTP_CODE})")
fi

# Actions (RBA terminology for Tools): use the RBA v1 API.
# The response is { "actions": [...] }; normalise to { "items": [...] } on save.
echo "Exporting Actions..."
ACT_TMP="${OUTPUT_DIR}/actions.json.tmp"
ACT_OUT="${OUTPUT_DIR}/actions.json"
ACT_URL="${CLUSTER_CPD_ENDPOINT}/aiops/api/story-manager/rba/v1/actions"

if [[ "$DEBUG" == "true" ]]; then
    echo "  [debug] GET ${ACT_URL}"
    ACT_HTTP_CODE=$(curl -k --compressed -X GET "${ACT_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${ACT_TMP}" \
        --write-out "%{http_code}" \
        --verbose 2>/dev/tty || true)
    echo "  [debug] Response body:"
    cat "${ACT_TMP}" 2>/dev/null || true
    echo ""
else
    ACT_HTTP_CODE=$(curl -k --compressed -X GET "${ACT_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${ACT_TMP}" \
        --write-out "%{http_code}" \
        --silent 2>/dev/null || true)
fi

ACT_HTTP_CODE="${ACT_HTTP_CODE//[^0-9]/}"

if [[ "${ACT_HTTP_CODE}" -ge 200 && "${ACT_HTTP_CODE}" -lt 300 ]]; then
    # Response is { "actions": [...] } — normalise to { "items": [...] }
    if jq '{"items": .actions}' "${ACT_TMP}" > "${ACT_OUT}" 2>/dev/null; then
        rm -f "${ACT_TMP}"
    else
        echo "  Error: Actions API returned non-JSON (HTTP ${ACT_HTTP_CODE})"
        echo "  Response body (first 500 chars):"
        head -c 500 "${ACT_TMP}"
        echo ""
        rm -f "${ACT_TMP}"
        exit 1
    fi
    local_item_count=$(jq '.items | length' "${ACT_OUT}" 2>/dev/null || echo "?")
    echo "  OK — ${local_item_count} item(s) → actions.json"
elif [[ "${ACT_HTTP_CODE}" -eq 401 || "${ACT_HTTP_CODE}" -eq 403 ]]; then
    echo "  Error: HTTP ${ACT_HTTP_CODE} (auth failure) while exporting Actions — aborting"
    echo "  Response body:"
    cat "${ACT_TMP}" 2>/dev/null || true
    echo ""
    rm -f "${ACT_TMP}"
    exit 1
else
    echo "  Warning: HTTP ${ACT_HTTP_CODE} while exporting Actions — skipping"
    echo "  Response body: $(cat "${ACT_TMP}" 2>/dev/null || true)"
    rm -f "${ACT_TMP}"
    SKIPPED_RESOURCES+=("Actions (HTTP ${ACT_HTTP_CODE})")
fi

fetch_resource \
    "Training definitions" \
    "/aiops/api/v2/configuration/training-definitions" \
    "training-definitions.json"

fetch_resource \
    "User preferences" \
    "/aiops/api/v2/configuration/user-preferences" \
    "user-preferences.json"

fetch_resource \
    "Views" \
    "/aiops/api/v2/configuration/views?all=true" \
    "views.json"

# Topology uses a dedicated backup endpoint that returns the full config blob
echo "Exporting Topology configuration..."
TOPOLOGY_TMP="${OUTPUT_DIR}/topology.json.tmp"
TOPOLOGY_OUT="${OUTPUT_DIR}/topology.json"
TOPO_URL="${CLUSTER_CPD_ENDPOINT}/aiops/api/v2/configuration/topology/config/backup"

if [[ "$DEBUG" == "true" ]]; then
    echo "  [debug] GET ${TOPO_URL}"
fi

if [[ "$DEBUG" == "true" ]]; then
    TOPO_HTTP_CODE=$(curl -k --compressed -X GET "${TOPO_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${TOPOLOGY_TMP}" \
        --write-out "%{http_code}" \
        --verbose 2>/dev/tty || true)
    echo "  [debug] Response body:"
    cat "${TOPOLOGY_TMP}" 2>/dev/null || true
    echo ""
else
    TOPO_HTTP_CODE=$(curl -k --compressed -X GET "${TOPO_URL}" \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255" \
        --output "${TOPOLOGY_TMP}" \
        --write-out "%{http_code}" \
        --silent 2>/dev/null || true)
fi

TOPO_HTTP_CODE="${TOPO_HTTP_CODE//[^0-9]/}"

if [[ "${TOPO_HTTP_CODE}" -ge 200 && "${TOPO_HTTP_CODE}" -lt 300 ]]; then
    if jq '.' "${TOPOLOGY_TMP}" > "${TOPOLOGY_OUT}" 2>/dev/null; then
        rm -f "${TOPOLOGY_TMP}"
    else
        echo "  Error: Topology API returned non-JSON (HTTP ${TOPO_HTTP_CODE})"
        echo "  Response body (first 500 chars):"
        head -c 500 "${TOPOLOGY_TMP}"
        echo ""
        rm -f "${TOPOLOGY_TMP}"
        exit 1
    fi
    echo "  OK → topology.json"
elif [[ "${TOPO_HTTP_CODE}" -eq 401 || "${TOPO_HTTP_CODE}" -eq 403 ]]; then
    echo "  Error: HTTP ${TOPO_HTTP_CODE} (auth failure) while exporting Topology — aborting"
    echo "  Response body:"
    cat "${TOPOLOGY_TMP}" 2>/dev/null || true
    echo ""
    rm -f "${TOPOLOGY_TMP}"
    exit 1
else
    echo "  Warning: HTTP ${TOPO_HTTP_CODE} while exporting Topology — skipping"
    echo "  Response body: $(cat "${TOPOLOGY_TMP}" 2>/dev/null || true)"
    rm -f "${TOPOLOGY_TMP}"
    SKIPPED_RESOURCES+=("Topology (HTTP ${TOPO_HTTP_CODE})")
fi

# ============================================
# Write backup metadata
# ============================================
METADATA_FILE="${OUTPUT_DIR}/backup-metadata.json"
cat > "${METADATA_FILE}" <<EOF
{
  "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "source_cluster": "${SOURCE_CLUSTER}",
  "cluster_endpoint": "${CLUSTER_CPD_ENDPOINT}",
  "resources": [
    "algorithms",
    "connections",
    "filters",
    "menus",
    "policies",
    "runbooks",
    "actions",
    "topology",
    "training-definitions",
    "user-preferences",
    "views"
  ]
}
EOF
echo ""
echo "Metadata written → backup-metadata.json"

# ============================================
# Summary
# ============================================
echo ""
echo "============================================"
echo " Backup complete"
echo "============================================"
echo " Source cluster  : ${SOURCE_CLUSTER}"
echo " Output directory: ${OUTPUT_DIR}"
echo " Files created:"
for f in "${OUTPUT_DIR}"/*.json; do
    echo "   $(basename "${f}")"
done
if [[ ${#SKIPPED_RESOURCES[@]} -gt 0 ]]; then
    echo ""
    echo " Skipped resources (not available on this cluster):"
    for r in "${SKIPPED_RESOURCES[@]}"; do
        echo "   - ${r}"
    done
fi
echo ""
echo "To commit to git:"
echo "  git add ${OUTPUT_DIR}"
echo "  git commit -m \"chore: config backup from ${SOURCE_CLUSTER} $(date -u +%Y-%m-%dT%H:%M:%SZ)\""
