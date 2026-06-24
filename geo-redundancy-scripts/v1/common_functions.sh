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
        local CP_ROUTE=$(oc get cm management-ingress-ibmcloud-cluster-info -o jsonpath={.data.cluster_endpoint})
        local ADMIN_USER=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
        local ADMIN_PASS=$(oc get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
        local IAM_ACCESS_TOKEN=$(curl -k -H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8" \
            -d "grant_type=password&username=${ADMIN_USER}&password=${ADMIN_PASS}&scope=openid" \
            ${CP_ROUTE}/idprovider/v1/auth/identitytoken | jq -r '.access_token')
        
        JWT_TOKEN=$(curl -k -X GET "${CLUSTER_CPD_ENDPOINT}/v1/preauth/validateAuth" \
            -H "username: ${ADMIN_USER}" \
            -H "iam-token: ${IAM_ACCESS_TOKEN}" | jq -r .accessToken)
    fi
    
    if [ -z "$JWT_TOKEN" ] || [ "$JWT_TOKEN" = "null" ]; then
        echo "Error: Failed to obtain JWT token"
        exit 1
    fi
    
    echo "JWT token obtained successfully"
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