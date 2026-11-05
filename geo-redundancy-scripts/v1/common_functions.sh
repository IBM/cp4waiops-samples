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
ALL_RESOURCES="algorithms connections filters menus tools policies runbooks actions topology training-definitions user-preferences views installation"

# Resources restored when --include / --exclude are not given. Resources known
# not to restore reliably in 5.4.0 (algorithms, training definitions, user
# preferences) are left out; they can still be restored with --include.
RESTORE_DEFAULT_RESOURCES="connections filters menus tools policies runbooks actions topology views installation"

# Files that make up the "installation" resource (Kubernetes resources saved as yaml).
# The names are fixed, even if the Installation CR or the Custom Properties ConfigMap
# have a different name on the cluster. An optional ConfigMap that does not exist is
# saved as an empty file, so a missing file always means an incomplete backup.
INSTALLATION_FILE="installation.yaml"
INSTALLATION_NCODL_FILE="ncodl-properties.yaml"
INSTALLATION_SIZE_PROFILE_FILE="aiops-custom-size-profile.yaml"
INSTALLATION_UI_CONFIG_FILE="aiops-ui-configurations.yaml"
INSTALLATION_FEATURE_FLAG_FILE="feature-flag-configmap.yaml"
INSTALLATION_PRODUCT_FILE="product-configmap.yaml"
# ConfigMap named by the optional Installation spec.resourceOverrides
INSTALLATION_RESOURCE_OVERRIDES_FILE="resource-overrides.yaml"

# Usage: resource_description <id>
resource_description() {
    case "$1" in
        algorithms)           echo "Algorithms" ;;
        connections)          echo "Connections" ;;
        filters)              echo "Filters" ;;
        menus)                echo "Menus" ;;
        tools)                echo "Tools" ;;
        policies)             echo "Policies" ;;
        runbooks)             echo "Runbooks" ;;
        actions)              echo "Runbook actions" ;;
        topology)             echo "Topology configuration" ;;
        training-definitions) echo "Training definitions" ;;
        user-preferences)     echo "User preferences" ;;
        views)                echo "Views" ;;
        installation)         echo "Installation CR and ConfigMaps (Kubernetes resources)" ;;
        *)                    echo "" ;;
    esac
}

# Usage: resource_files <id>
# Prints the backup file name(s) that make up a resource.
resource_files() {
    case "$1" in
        connections) echo "connections.json connections-internal.json connections-runbooks.json" ;;
        topology)    echo "topology.json" ;;
        installation) echo "${INSTALLATION_FILE} ${INSTALLATION_NCODL_FILE} ${INSTALLATION_SIZE_PROFILE_FILE} ${INSTALLATION_UI_CONFIG_FILE} ${INSTALLATION_FEATURE_FLAG_FILE} ${INSTALLATION_PRODUCT_FILE} ${INSTALLATION_RESOURCE_OVERRIDES_FILE}" ;;
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

# ============================================
# Installation resource (Kubernetes resources, synced with oc / yq)
# ============================================
# Shared by backup.sh (backup_installation) and restore.sh (restore_installation).
# See kube-syncing.md for the design. In short:
#   - backup saves the Installation CR and its ConfigMaps as yaml, unvalidated
#   - restore applies only the Installation spec fields on the allow list, and the
#     ConfigMap data, with server-side apply. Nothing is ever deleted on the target
#
# Errors: every helper that can fail prints "  ERROR: <message>" to stderr and returns 1.
# The caller (backup_installation / restore_installation) stops processing the
# installation resource only, so the other resources continue and the exit code is
# not changed (as with the other resources, failures are only logged).

INSTALLATION_CRD="installations.orchestrator.aiops.ibm.com"
KUBE_SYNC_FIELD_MANAGER="backup-restore-sync"

# A customer allowlist entry that is not in this list is rejected.
# Although these specs are supported, not all of them should be synchronized. In special cases
# where both clusters have the same value, the Administrator can select it. Otherwise the safest
# fields are the ones defined in DEFAULT_INSTALLATION_SPEC_ALLOWLIST
SUPPORTED_INSTALLATION_SPEC_FIELDS=(
    "spec.license"
    "spec.topologyModel"
    "spec.enableConnectionModule"
    "spec.groupProfiles"
    "spec.monitoring"
    "spec.pakModules"
    "spec.automationFoundation"
    "spec.resourceOverrides"
    "spec.customPropertiesConfigMap"
    "spec.size"
    "spec.storageClass"
    "spec.storageClassLargeBlock"
    "spec.storage"
    "spec.zones"
    "spec.multiCluster"
    "spec.proxyServer"
    "spec.imagePullSecret"
)

# Used when INSTALLATION_SPEC_ALLOWLIST is not defined in geo_config.env.
DEFAULT_INSTALLATION_SPEC_ALLOWLIST=(
    "spec.topologyModel"
    "spec.enableConnectionModule"
    "spec.groupProfiles"
    "spec.monitoring"
    "spec.pakModules"
    "spec.automationFoundation"
    "spec.resourceOverrides"
)

installation_error() {
    echo "  ERROR: $*" >&2
}

# Usage: yaml_is_empty <yaml string>   (true for an empty or whitespace-only string)
# A regex match is used on purpose: "${1//[[:space:]]/}" is quadratic on bash 3.2 and hangs on large yaml.
yaml_is_empty() {
    [[ ! "$1" =~ [^[:space:]] ]]
}

# Usage: yaml_get <yaml string> <yq expression>
yaml_get() {
    printf '%s\n' "$1" | yq "$2"
}

# Checks oc, jq and the mikefarah yq (v4) are available.
installation_check_tools() {
    local tool
    for tool in oc jq yq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            installation_error "'${tool}' is required for the installation resource but was not found on the PATH"
            return 1
        fi
    done
    if ! yq --version 2>&1 | grep -q "mikefarah"; then
        installation_error "The installation resource requires yq v4 from https://github.com/mikefarah/yq"
        return 1
    fi
}

# Prints the Installation CR yaml (the first item), nothing if the namespace has none.
# Usage: get_installation_cr <namespace>
get_installation_cr() {
    local ns="$1" raw
    # The Installation name is dynamic and only one exists per namespace
    if ! raw=$(oc get "${INSTALLATION_CRD}" -n "${ns}" -o yaml 2>&1); then
        installation_error "Could not read the Installation in namespace ${ns}: $(printf '%s' "$raw" | head -c 300)"
        return 1
    fi
    if ! yaml_get "$raw" '(.items // [])[0] // ""'; then
        installation_error "Could not parse the Installation returned by the cluster"
        return 1
    fi
}

# Prints the ConfigMap yaml, nothing if it does not exist.
# Usage: get_configmap <namespace> <name>
get_configmap() {
    local ns="$1" name="$2" raw
    if ! raw=$(oc get configmap "${name}" -n "${ns}" --ignore-not-found -o yaml 2>&1); then
        installation_error "Could not read ConfigMap ${name} in namespace ${ns}: $(printf '%s' "$raw" | head -c 300)"
        return 1
    fi
    printf '%s\n' "$raw"
}

# Prints the name of the Custom Properties ConfigMap referenced by the Installation, nothing if not configured.
# Usage: get_properties_configmap_name <installation yaml>
get_properties_configmap_name() {
    if ! yaml_get "$1" '[.spec.pakModules[]?.config[]? | select(.name == "ir-core-operator") | .spec.issueresolutioncore.ncodl.propertiesConfigMapName][0] // ""'; then
        installation_error "Could not read the Custom Properties ConfigMap name from the Installation"
        return 1
    fi
}

# Prints the name of the ConfigMap in spec.resourceOverrides (optional), nothing if not set.
# Usage: get_resource_overrides_configmap_name <installation yaml>
get_resource_overrides_configmap_name() {
    if ! yaml_get "$1" '.spec.resourceOverrides // ""'; then
        installation_error "Could not read spec.resourceOverrides from the Installation"
        return 1
    fi
}

# Sets INSTALLATION_ALLOWLIST (array) from geo_config.env or the default list.
# Call after load_geo_config.
load_installation_allowlist() {
    local field
    INSTALLATION_ALLOWLIST=()

    if ! declare -p INSTALLATION_SPEC_ALLOWLIST >/dev/null 2>&1; then
        INSTALLATION_ALLOWLIST=("${DEFAULT_INSTALLATION_SPEC_ALLOWLIST[@]}")
        return 0
    fi
    if [[ ${#INSTALLATION_SPEC_ALLOWLIST[@]} -eq 0 ]]; then
        installation_error "INSTALLATION_SPEC_ALLOWLIST is empty. Add at least one field or remove the property to use the default list"
        return 1
    fi
    for field in "${INSTALLATION_SPEC_ALLOWLIST[@]}"; do
        if ! resource_in_list "$field" "${SUPPORTED_INSTALLATION_SPEC_FIELDS[*]}"; then
            installation_error "Unsupported field ${field} found in INSTALLATION_SPEC_ALLOWLIST"
            return 1
        fi
    done
    INSTALLATION_ALLOWLIST=("${INSTALLATION_SPEC_ALLOWLIST[@]}")
}

# The product versions of both clusters must match exactly (for example 5.3.0 vs 5.3.1 is not compatible).
# Usage: is_product_version_compatible <source product-configmap yaml> <target product-configmap yaml>
is_product_version_compatible() {
    local source_version target_version
    source_version=$(yaml_get "$1" '.data.PRODUCT_VERSION // ""') || { installation_error "Could not parse the product ConfigMap"; return 1; }
    target_version=$(yaml_get "$2" '.data.PRODUCT_VERSION // ""') || { installation_error "Could not parse the product ConfigMap"; return 1; }
    if [[ -z "$source_version" || -z "$target_version" ]]; then
        installation_error "PRODUCT_VERSION could not be read from the product ConfigMap"
        return 1
    fi
    if [[ "$source_version" != "$target_version" ]]; then
        installation_error "Product versions are incompatible (backup: ${source_version}, cluster: ${target_version})"
        return 1
    fi
}

# The sizes must match: the size cannot change after install and the target needs enough resources.
# Usage: is_installation_compatible <source installation yaml> <target installation yaml>
is_installation_compatible() {
    local source_size target_size
    source_size=$(yaml_get "$1" '.spec.size // ""') || { installation_error "Could not parse the Installation"; return 1; }
    target_size=$(yaml_get "$2" '.spec.size // ""') || { installation_error "Could not parse the Installation"; return 1; }
    if [[ -z "$source_size" || -z "$target_size" ]]; then
        installation_error "spec.size could not be read from the Installation"
        return 1
    fi
    if [[ "$source_size" != "$target_size" ]]; then
        installation_error "Size mismatch detected and are incompatible (backup: ${source_size}, cluster: ${target_size})"
        return 1
    fi
}

# Builds the Installation to apply to the target.
#
# Context on Required Fields & Cluster-Specific Values:
# The Installation CRD OpenAPI validation schema defines mandatory fields in spec:
#   - spec.license: Required value
#   - spec.storageClass: Required value
#   - spec.storageClassLargeBlock: Required value
#   - spec.size: Required value
# Omitting these fields from the manifest causes Kubernetes OpenAPI schema validation to fail
# and reject the apply request.
#
# Safety Policy:
# 1. Cluster-specific Installation CR settings (such as storage classes and licenses) are preserved
#    from target_yaml so they are never overwritten or corrupted by the backup.
# 2. Allowlisted fields existing on the target cluster (e.g. topologyModel) that are NOT defined
#    in the incoming backup are preserved and NOT deleted for safety.
# 3. Allowlisted fields explicitly specified in the backup (e.g. pakModules) are overlaid on top.
#
# Usage: transform_installation <source installation yaml> <target installation yaml> <target namespace>
transform_installation() {
    local source_yaml="$1" target_yaml="$2" ns="$3"
    local target_name api_version kind allow_json

    target_name=$(yaml_get "$target_yaml" '.metadata.name // ""') || { installation_error "Could not parse the Installation"; return 1; }
    api_version=$(yaml_get "$source_yaml" '.apiVersion // ""') || { installation_error "Could not parse the Installation"; return 1; }
    kind=$(yaml_get "$source_yaml" '.kind // ""') || { installation_error "Could not parse the Installation"; return 1; }
    if [[ -z "$target_name" || -z "$api_version" || -z "$kind" ]]; then
        installation_error "The Installation yaml is missing a required field"
        return 1
    fi

    # "spec.license" -> "license"; the allow list holds top level spec fields
    allow_json=$(printf '%s\n' "${INSTALLATION_ALLOWLIST[@]}" | sed 's/^spec\.//' | jq -R . | jq -sc .)

    # 1. Take target cluster's required baseline fields: license, size, storageClass, storageClassLargeBlock
    # 2. Preserve target's allowlisted fields if absent in the backup (non-destructive safety)
    # 3. Overlay the source's defined allowlisted fields onto it
    printf '%s\n' "$source_yaml" | yq -o=json '.' | jq \
        --arg name "$target_name" --arg ns "$ns" --arg apiVersion "$api_version" --arg kind "$kind" \
        --argjson allow "$allow_json" \
        --argjson target "$(printf '%s\n' "$target_yaml" | yq -o=json '.')" \
        '{
          apiVersion: $apiVersion,
          kind: $kind,
          metadata: {name: $name, namespace: $ns},
          spec: (
            (
              ((($target.spec // {}) | {
                license: .license,
                size: .size,
                storageClass: .storageClass,
                storageClassLargeBlock: .storageClassLargeBlock
              }) | with_entries(select(.value != null)))
              +
              (($target.spec // {}) | with_entries(select(.key as $k | $allow | index($k) != null)))
            )
            +
            ((.spec // {}) | with_entries(select(.key as $k | $allow | index($k) != null)))
          )
        }' \
        | yq -p=json -o=yaml '.' || { installation_error "Could not transform the Installation"; return 1; }
}

# Builds the ConfigMap to apply to the target: name, namespace, apiVersion, kind and data.
# An empty input (the ConfigMap did not exist at the source) prints nothing, so it is not applied
# and the target's ConfigMap is left as is.
# Usage: transform_configmap <target namespace> <configmap yaml>
transform_configmap() {
    local ns="$1" cm_yaml="$2" name api_version kind
    if yaml_is_empty "$cm_yaml"; then
        return 0
    fi
    name=$(yaml_get "$cm_yaml" '.metadata.name // ""') || { installation_error "Could not parse the ConfigMap"; return 1; }
    api_version=$(yaml_get "$cm_yaml" '.apiVersion // ""') || { installation_error "Could not parse the ConfigMap"; return 1; }
    kind=$(yaml_get "$cm_yaml" '.kind // ""') || { installation_error "Could not parse the ConfigMap"; return 1; }
    if [[ -z "$name" || -z "$api_version" || -z "$kind" ]]; then
        installation_error "The ConfigMap yaml is missing a required field"
        return 1
    fi
    printf '%s\n' "$cm_yaml" | NS="$ns" yq \
        '{"apiVersion": .apiVersion, "kind": .kind, "metadata": {"name": .metadata.name, "namespace": strenv(NS)}, "data": (.data // {})}' \
        || { installation_error "Could not transform the ConfigMap"; return 1; }
}

# Server-side apply of one yaml document to the cluster oc is logged in to.
# Returns 0 on success, 2 if the yaml is empty (skipped), 1 on error. Honors DRY_RUN (restore.sh).
#
# Context on SSA Migration Warnings:
# When resources were previously managed via Client-Side Apply (standard `oc apply`),
# Kubernetes leaves a `kubectl.kubernetes.io/last-applied-configuration` annotation.
# When `oc apply --server-side` runs against such resources, the kubectl/oc client attempts
# an automatic client-side-to-server-side migration. Because we apply a projected/partial
# manifest containing only allowlisted fields, the client-side migration validator logs a
# warning complaining about missing CRD-required fields (e.g. spec.license, spec.storageClass).
# This warning is completely non-fatal: the Kubernetes API server itself accepts the partial
# Server-Side Apply patch and successfully updates and owns the allowlisted fields.
# We filter out this benign client-side migration noise to keep output clear.
#
# Usage: apply_kube_yaml <label> <yaml>
apply_kube_yaml() {
    local label="$1" yaml="$2" out rc=0
    if yaml_is_empty "$yaml"; then
        echo "  Skipping ${label} — not present in the backup"
        return 2
    fi
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        echo "  [dry-run] Would apply ${label}"
        return 2
    fi
    out=$(printf '%s\n' "$yaml" | oc apply --server-side --field-manager="${KUBE_SYNC_FIELD_MANAGER}" --force-conflicts -f - 2>&1) || rc=$?
    if [[ $rc -ne 0 ]]; then
        installation_error "Failed to apply ${label}: $(printf '%s' "$out" | head -c 300)"
        return 1
    fi

    # Filter out known non-fatal client-side SSA migration warnings for partial manifests
    out=$(printf '%s\n' "$out" | \
        grep -v "failed to re-apply configuration after performing Server-Side Apply migration" | \
        grep -v -E "is invalid: \[.*Required value" | \
        sed '/^[[:space:]]*$/d')

    echo "  Applied ${label}: ${out}"
}

# Normalizes YAML documents by sorting keys recursively and sorting object sequences by .name.
# Usage: normalize_yaml <yaml string>
normalize_yaml() {
    printf '%s\n' "$1" | yq -P '
      sort_keys(..) |
      (.. | select(tag == "!!seq" and length > 0 and (.[0] | (tag == "!!map" and has("name"))))) |= sort_by(.name)
    '
}

# True when two yaml documents are identical once keys and keyed lists are normalized.
# Usage: yaml_equal <yaml a> <yaml b>
yaml_equal() {
    local a b
    a=$(normalize_yaml "$1") || return 1
    b=$(normalize_yaml "$2") || return 1
    [[ "$a" == "$b" ]]
}

# Prints a unified diff of two yaml documents (keys and keyed lists sorted so only real changes show).
# Usage: diff_yaml <current yaml> <new yaml>
diff_yaml() {
    local a b rc=0
    a=$(mktemp); b=$(mktemp)
    normalize_yaml "$1" > "$a"
    normalize_yaml "$2" > "$b"
    diff -u -L "cluster (before)" -L "restored (after)" "$a" "$b" || rc=$?
    rm -f "$a" "$b"
    if [[ $rc -eq 0 ]]; then
        echo "  (no changes to the allow listed Installation fields)"
    fi
    return 0
}
