#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2026
# 
# 
#
# Common functions for geo-redundancy scripts
# This file should be sourced by other scripts, not executed directly

# ============================================
# Load Configuration
# ============================================
load_geo_config() {
    # Allow user to specify config file location via environment variable or argument
    # CONFIG_FILE_PATH can be set by parse_arguments function. This can allow the
    # config file to be stored outside of the repo, to avoid being overwritten
    # during version updates
    GEO_CONFIG_FILE="${CONFIG_FILE_PATH:-${GEO_CONFIG_FILE:-./geo_config.env}}"

    # Check if config file exists
    if [ ! -f "$GEO_CONFIG_FILE" ]; then
        echo "Error: Configuration file not found at: $GEO_CONFIG_FILE"
        echo "Please create geo_config.env from geo_config.env.template"
        echo "Or use --config option to specify a different config file"
        exit 1
    fi

    # Set environment variables
    set -a
    source "$GEO_CONFIG_FILE"
    set +a
}

# ============================================
# Parse Arguments (Cluster and Config)
# ============================================
# Usage: parse_arguments "default_cluster" "$@"
# Returns: Sets SELECTED_CLUSTER, CONFIG_FILE_PATH, and REMAINING_ARGS variables
# Returns 1 if help was requested, 2 if error
parse_arguments() {
    local default_cluster="$1"
    shift
    
    SELECTED_CLUSTER="$default_cluster"
    CONFIG_FILE_PATH=""
    REMAINING_ARGS=()
    
    # Parse all arguments - only support --cluster and --config flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                return 1  # Signal that help was requested
                ;;
            --cluster)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --cluster requires a value (primary or backup)"
                    return 2
                fi
                SELECTED_CLUSTER="$2"
                shift 2
                ;;
            --config)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --config requires a file path"
                    return 2
                fi
                CONFIG_FILE_PATH="$2"
                shift 2
                ;;
            *)
                # Unknown argument - save it for calling script
                REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # Validate cluster selection
    if [[ "$SELECTED_CLUSTER" != "primary" && "$SELECTED_CLUSTER" != "backup" ]]; then
        echo "Error: Invalid cluster specified: $SELECTED_CLUSTER"
        echo "Must be either 'primary' or 'backup'"
        return 2
    fi
    
    return 0
}

# ============================================
# Validate Cluster Selection
# ============================================
validate_cluster() {
    local cluster="$1"
    
    if [[ "$cluster" != "primary" && "$cluster" != "backup" ]]; then
        echo "Error: Invalid cluster specified: $cluster"
        echo "Must be either 'primary' or 'backup'"
        exit 1
    fi
}

# ============================================
# Set Cluster Variables
# ============================================
# Usage: set_cluster_vars "primary|backup"
# Sets: CLUSTER_API_ENDPOINT, CLUSTER_TOKEN, CLUSTER_NAMESPACE, CLUSTER_CPD_ENDPOINT, ACCESS_TOKEN
set_cluster_vars() {
    local cluster="$1"
    
    validate_cluster "$cluster"
    
    if [ "$cluster" = "backup" ]; then
        CLUSTER_API_ENDPOINT="$BACKUP_CLUSTER_API_ENDPOINT"
        CLUSTER_TOKEN="$BACKUP_CLUSTER_TOKEN"
        CLUSTER_NAMESPACE="$BACKUP_CLUSTER_NAMESPACE"
        CLUSTER_CPD_ENDPOINT="$BACKUP_CLUSTER_CPD_ENDPOINT"
        CLUSTER_NAME="$BACKUP_CLUSTER_NAME"
        ACCESS_TOKEN="${BACKUP_ACCESS_TOKEN:-}"
    else
        CLUSTER_API_ENDPOINT="$PRIMARY_CLUSTER_API_ENDPOINT"
        CLUSTER_TOKEN="$PRIMARY_CLUSTER_TOKEN"
        CLUSTER_NAMESPACE="$PRIMARY_CLUSTER_NAMESPACE"
        CLUSTER_CPD_ENDPOINT="$PRIMARY_CLUSTER_CPD_ENDPOINT"
        CLUSTER_NAME="$PRIMARY_CLUSTER_NAME"
        ACCESS_TOKEN="${PRIMARY_ACCESS_TOKEN:-}"
    fi
}

# ============================================
# oc Login
# ============================================
# Usage: oc_login "primary|backup"
oc_login() {
    local cluster="$1"
    
    set_cluster_vars "$cluster"
    
    echo "Performing oc login into cluster: ${cluster}"
    oc login "${CLUSTER_API_ENDPOINT}" \
        --token="${CLUSTER_TOKEN}" \
        --insecure-skip-tls-verify=true
    
    # Switch to the correct namespace
    oc project "${CLUSTER_NAMESPACE}"
}

# ============================================
# Get JWT Token
# ============================================
# Usage: get_jwt_token
# Requires: Must be logged into cluster via oc login first
# Sets: JWT_TOKEN variable
# Note: If ACCESS_TOKEN is already set (from PRIMARY_ACCESS_TOKEN or BACKUP_ACCESS_TOKEN),
#       it will be used directly as the JWT token, skipping the authentication flow
get_jwt_token() {
    echo "Getting JWT token..."
    
    # Check if ACCESS_TOKEN is already provided (manual token)
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "Using provided access token as JWT token..."
        JWT_TOKEN="$ACCESS_TOKEN"
    else
        echo "Retrieving credentials from platform-auth-idp-credentials secret..."
        # Declare locals first so 'local' exit-code doesn't mask subshell failures
        local CP_ROUTE ADMIN_USER ADMIN_PASS IAM_RESPONSE IAM_ACCESS_TOKEN JWT_RESPONSE
        CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
        ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
        ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)

        IAM_RESPONSE=$(curl -sk -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" \
            -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" \
            "${CP_ROUTE}/idprovider/v1/auth/identitytoken")
        # Use || true so a jq parse failure doesn't kill the script via set -e;
        # the emptiness check below provides the real error gate.
        IAM_ACCESS_TOKEN=$(echo "${IAM_RESPONSE}" | jq -r '.access_token // empty' 2>/dev/null || true)

        if [ -z "$IAM_ACCESS_TOKEN" ]; then
            echo "Error: Failed to obtain IAM access token"
            echo "IAM endpoint: ${CP_ROUTE}/idprovider/v1/auth/identitytoken"
            echo "Response: ${IAM_RESPONSE}"
            exit 1
        fi

        JWT_RESPONSE=$(curl -sk -X GET "${CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
            -H "username: ${ADMIN_USER}" \
            -H "iam-token: ${IAM_ACCESS_TOKEN}")
        JWT_TOKEN=$(echo "${JWT_RESPONSE}" | jq -r '.accessToken // empty' 2>/dev/null || true)

        if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
            echo "Error: Failed to obtain JWT token from validateAuth"
            echo "validateAuth endpoint: ${CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth"
            echo "Response: ${JWT_RESPONSE}"
            exit 1
        fi
    fi
    
    if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
        echo "Error: Failed to obtain JWT token"
        exit 1
    fi
    
    echo "JWT token obtained successfully"
}

# ============================================
# Resolve Topology API Base Path
# ============================================
# Usage: resolve_topology_endpoint
# Requires: CLUSTER_CPD_ENDPOINT and JWT_TOKEN must be set (call after login_and_get_token)
# Sets: TOPOLOGY_API_BASE — the base path prefix used for topology backup/restore calls.
#
# Tries the new endpoint first:
#   /aiops/api/v2/topology/service/info
# Falls back to the legacy endpoint on a 404 response:
#   /aiops/api/v2/configuration/topology/config
#
# The result is cached in TOPOLOGY_API_BASE so this probe runs only once per
# script execution regardless of how many topology calls follow.
resolve_topology_endpoint() {
    # Return immediately if already resolved
    if [ -n "${TOPOLOGY_API_BASE:-}" ]; then
        return 0
    fi

    # New endpoint is for version 5.2.0 of Concert Operate and after
    local new_base="/aiops/api/v2/topology/service/info"

    # Legacy endpoint is for version 5.1.x of Concert Operate
    local legacy_base="/aiops/api/v2/configuration/topology/config"

    echo "Detecting topology API endpoint..."
    local http_code
    http_code=$(curl -k -s -o /dev/null -w "%{http_code}" \
        -X GET "${CLUSTER_CPD_ENDPOINT}${new_base}/backup" \
        --header "Authorization: Bearer ${JWT_TOKEN}" \
        --header "X-TenantID: cfd95b7e-3bc7-4006-a4a8-a73a79c71255")

    if [ "${http_code}" -eq 404 ]; then
        echo "New topology endpoint not available (HTTP ${http_code}), falling back to: ${legacy_base}"
        TOPOLOGY_API_BASE="${legacy_base}"
    else
        echo "Topology endpoint detected (HTTP ${http_code}): ${new_base}"
        TOPOLOGY_API_BASE="${new_base}"
    fi
}

# ============================================
# Login and Get Token (Combined)
# ============================================
# Usage: login_and_get_token "primary|backup"
# Sets: CLUSTER_* variables and JWT_TOKEN
# Note: If ACCESS_TOKEN is provided, skips oc login and uses the token directly
login_and_get_token() {
    local cluster="$1"
    
    # Set cluster variables first to get ACCESS_TOKEN
    set_cluster_vars "$cluster"
    
    # Check if manual access token is provided
    if [ -n "$ACCESS_TOKEN" ]; then
        echo "Using provided access token, skipping oc login..."
        JWT_TOKEN="$ACCESS_TOKEN"
        
        if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
            echo "Error: Provided access token is invalid"
            exit 1
        fi
        
        echo "JWT token set successfully from provided access token"
    else
        # No manual token, perform normal oc login and get token
        oc_login "$cluster"
        get_jwt_token
    fi
}
# ============================================
# Resource selection (--include / --exclude / --list-resources)
# ============================================
# Registry of the resource IDs understood by backup.sh and restore.sh.
# To add a new resource: add its ID here, describe it in resource_description,
# list its backup files in resource_files, then add a backup_<id> function to
# backup.sh and a restore step to restore.sh.
# Plain strings and case statements are used (no associative arrays) so the
# scripts keep working with bash 3.2 (the macOS default).
ALL_RESOURCES="algorithms connections filters menus policies runbooks actions topology training-definitions user-preferences views"

# Resources restored when --include / --exclude are not given. Resources known
# not to restore reliably in 5.4.0 (algorithms, training definitions, user
# preferences) are left out; they can still be restored with --include.
RESTORE_DEFAULT_RESOURCES="connections filters menus policies runbooks actions topology views"

# Usage: resource_description <id>
resource_description() {
    case "$1" in
        algorithms)           echo "Algorithms" ;;
        connections)          echo "Connections" ;;
        filters)              echo "Filters" ;;
        menus)                echo "Menus" ;;
        policies)             echo "Policies" ;;
        runbooks)             echo "Runbooks" ;;
        actions)              echo "Runbook actions" ;;
        topology)             echo "Topology configuration" ;;
        training-definitions) echo "Training definitions" ;;
        user-preferences)     echo "User preferences" ;;
        views)                echo "Views" ;;
        *)                    echo "" ;;
    esac
}

# Usage: resource_files <id>
# Prints the backup file name(s) that make up a resource.
resource_files() {
    case "$1" in
        connections) echo "connections.json connections-internal.json connections-runbooks.json" ;;
        topology)    echo "topology.json" ;;
        *)           echo "$1.json" ;;
    esac
}

# Usage: resource_in_list <id> <space-separated list>
resource_in_list() {
    case " $2 " in
        *" $1 "*) return 0 ;;
        *)        return 1 ;;
    esac
}

# Usage: resource_selected <id>   (after resolve_resource_selection)
resource_selected() {
    resource_in_list "$1" "${SELECTED_RESOURCES:-}"
}

# Usage: list_resources
list_resources() {
    local id marker
    echo "Valid resource IDs:"
    echo ""
    printf '  %-22s %-16s %s\n' "ID" "RESTORE DEFAULT" "DESCRIPTION"
    for id in ${ALL_RESOURCES}; do
        if resource_in_list "$id" "${RESTORE_DEFAULT_RESOURCES}"; then
            marker="yes"
        else
            marker="no"
        fi
        printf '  %-22s %-16s %s\n' "$id" "$marker" "$(resource_description "$id")"
    done
    echo ""
    echo "backup.sh : with no flags every resource is backed up."
    echo "restore.sh: with no flags only the resources marked 'yes' are restored."
}

# Usage: parse_selection_arguments "${REMAINING_ARGS[@]}"
# Consumes --include, --exclude and --list-resources, and sets:
#   INCLUDE_LIST, EXCLUDE_LIST (comma-separated, may be empty)
#   INCLUDE_GIVEN, EXCLUDE_GIVEN, LIST_RESOURCES (true|false)
# REMAINING_ARGS is rebuilt with the other arguments only.
# Returns 2 on error.
parse_selection_arguments() {
    INCLUDE_LIST=""
    EXCLUDE_LIST=""
    INCLUDE_GIVEN=false
    EXCLUDE_GIVEN=false
    LIST_RESOURCES=false
    local rest=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --include|--exclude)
                if [[ -z "${2:-}" || "${2}" == --* ]]; then
                    echo "Error: $1 requires a comma-separated list of resource IDs (see --list-resources)"
                    return 2
                fi
                if [[ "$1" == "--include" ]]; then
                    INCLUDE_LIST="$2"
                    INCLUDE_GIVEN=true
                else
                    EXCLUDE_LIST="$2"
                    EXCLUDE_GIVEN=true
                fi
                shift 2
                ;;
            --list-resources)
                LIST_RESOURCES=true
                shift
                ;;
            *)
                rest+=("$1")
                shift
                ;;
        esac
    done

    if [[ "$INCLUDE_GIVEN" == "true" && "$EXCLUDE_GIVEN" == "true" ]]; then
        echo "Error: --include and --exclude cannot be used together"
        return 2
    fi

    REMAINING_ARGS=()
    if [[ ${#rest[@]} -gt 0 ]]; then
        REMAINING_ARGS=("${rest[@]}")
    fi
    return 0
}

# Usage: validate_resource_list <comma-separated list> ; prints an error and returns 2 on unknown IDs
validate_resource_list() {
    local csv="$1"
    local items id invalid=""
    IFS=',' read -r -a items <<< "$csv"
    for id in "${items[@]}"; do
        id="${id// /}"
        if [[ -z "$id" ]] || ! resource_in_list "$id" "${ALL_RESOURCES}"; then
            invalid="${invalid} ${id:-<empty>}"
        fi
    done
    if [[ -n "$invalid" ]]; then
        echo "Error: unknown resource ID(s):${invalid}"
        echo "Valid resource IDs: ${ALL_RESOURCES}"
        echo "Run with --list-resources for details."
        return 2
    fi
    return 0
}

# Usage: resolve_resource_selection <default space-separated resource list>
# Uses INCLUDE_LIST / EXCLUDE_LIST from parse_selection_arguments and sets
# SELECTED_RESOURCES (space-separated, registry order). Returns 2 on error.
# Must run before any login or API call.
resolve_resource_selection() {
    local default_set="$1"
    local id items=() selected=""

    SELECTED_RESOURCES=""
    if [[ "$INCLUDE_GIVEN" == "true" ]]; then
        validate_resource_list "$INCLUDE_LIST" || return 2
        IFS=',' read -r -a items <<< "${INCLUDE_LIST// /}"
        for id in ${ALL_RESOURCES}; do
            if resource_in_list "$id" "${items[*]}"; then
                selected="${selected}${selected:+ }${id}"
            fi
        done
    elif [[ "$EXCLUDE_GIVEN" == "true" ]]; then
        validate_resource_list "$EXCLUDE_LIST" || return 2
        IFS=',' read -r -a items <<< "${EXCLUDE_LIST// /}"
        for id in ${default_set}; do
            if ! resource_in_list "$id" "${items[*]}"; then
                selected="${selected}${selected:+ }${id}"
            fi
        done
    else
        selected="$default_set"
    fi

    if [[ -z "$selected" ]]; then
        echo "Error: the selection leaves no resources to process"
        return 2
    fi
    SELECTED_RESOURCES="$selected"
    return 0
}
