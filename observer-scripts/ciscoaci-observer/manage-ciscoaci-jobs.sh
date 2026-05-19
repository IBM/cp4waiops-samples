#!/bin/bash
#set -x

################################################################################
# Script: manage-ciscoaci-jobs.sh
# Description: Unified script to manage Cisco ACI observer jobs via API
# Usage: ./manage-ciscoaci-jobs.sh <action> <input-file> [log-file-path]
# Actions: create, update, stop, delete, status (case-insensitive)
# Examples: 
#   ./manage-ciscoaci-jobs.sh create cisco-jobs-sample.json
#   ./manage-ciscoaci-jobs.sh stop jobs-to-stop.txt
#   ./manage-ciscoaci-jobs.sh status jobs-to-check.json /path/to/logs/
################################################################################

set -o pipefail

################################################################################
# Configuration: Failure Handling Behavior (for create/update actions)
################################################################################
# CONTINUE_ON_FAILURE: Controls script behavior when a job operation fails
# - false (default): Stop script execution on first failure
# - true: Continue processing remaining jobs even if some fail
################################################################################
CONTINUE_ON_FAILURE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
ACTION=""
JOBS_FILE=""
LOG_FILE=""
LOG_DIR=""
NAMESPACE=""
API_USERNAME=""
API_PASSWORD=""
OBSERVER_BASE_URL=""
TOPOLOGY_BASE_URL=""
TENANT_ID="cfd95b7e-3bc7-4006-a4a8-a73a79c71255"
TOTAL_JOBS=0
SUCCESS_COUNT=0
FAILED_COUNT=0
ASYNC_COUNT=0
NOT_FOUND_COUNT=0
RUNNING_COUNT=0
SKIPPED_COUNT=0
EXPORT_FILE=""
EXPORT_SUBDIR=""
FETCH_FAILED=0
INCLUDE_SECRETS=false
APIC_PASSWORD=""
TRUSTSTORE_PASSWORD=""
ENCRYPTED_APIC_PASSWORD=""
ENCRYPTED_TRUSTSTORE_PASSWORD=""
TOPOLOGY_POD=""
DIR_INPUT=false
DIR_INPUT_PATH=""
DIR_MERGED_TMPFILE=""

################################################################################
# Logging Functions
################################################################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

################################################################################
# Function: display_usage
# Description: Show usage information
################################################################################
display_usage() {
    echo "Usage: $0 <action> [input-file] [log-file-path] [options]"
    echo ""
    echo "Actions: create, update, stop, delete, status, export (case-insensitive)"
    echo ""
    echo "Parameters:"
    echo "  action         - Action to perform (required)"
    echo "  input          - JSON file, TXT file, or directory with job data"
    echo "                   (required for all actions except export)"
    echo "                   For create/update: pass a .json file OR a directory"
    echo "                   containing .json files (all are merged and processed)"
    echo "                   For stop/delete/status: pass a .json or .txt file"
    echo "  log-file-path  - Optional directory path for log file (default: current directory)"
    echo ""
    echo "Options (create/update):"
    echo "  --apic-password <password>       Cleartext APIC password to encrypt and inject"
    echo "                                   into ciscoapic_password for all jobs"
    echo "  --truststore-password <password>  Cleartext SSL truststore password to encrypt"
    echo "                                   and inject into password_ssl_truststore_file"
    echo ""
    echo "Options (export):"
    echo "  --include-secrets                Include encrypted password fields in export"
    echo "                                   (ciscoapic_password, password_ssl_truststore_file)"
    echo ""
    echo "Examples:"
    echo "  $0 create cisco-jobs.json"
    echo "  $0 create /path/to/job-dir/"
    echo "  $0 create cisco-jobs.json --apic-password 'MyPass' --truststore-password 'TrustPass'"
    echo "  $0 update /path/to/job-dir/ --apic-password 'MyPass'"
    echo "  $0 stop jobs.txt"
    echo "  $0 export"
    echo "  $0 export --include-secrets"
    echo "  $0 export /path/to/output/ --include-secrets"
    echo "    (with dir: writes per-job <name>.json files + combined all-jobs.json)"
    echo ""
}

################################################################################
# Function: validate_action
# Description: Validate and normalize the action parameter
################################################################################
validate_action() {
    local input_action="$1"
    
    # Convert to lowercase for comparison
    local action_lower=$(echo "$input_action" | tr '[:upper:]' '[:lower:]')
    
    case "$action_lower" in
        create|update|stop|delete|status|export)
            ACTION="$action_lower"
            ;;
        *)
            log_error "Invalid action: $input_action"
            log_error "Valid actions: create, update, stop, delete, status, export"
            display_usage
            exit 1
            ;;
    esac
}

################################################################################
# Function: resolve_directory_input
# Description: If the input path is a directory, find all .json files inside,
#              validate each one, and merge them into a single temporary JSON
#              array file.  Sets JOBS_FILE to the merged temp file and marks
#              DIR_INPUT=true so the temp file is cleaned up on exit.
#              Only applicable for create/update actions.
################################################################################
resolve_directory_input() {
    local input_path="$1"

    # Not a directory -- nothing to do
    if [ ! -d "$input_path" ]; then
        return 0
    fi

    # Only create/update support directory input
    if [ "$ACTION" != "create" ] && [ "$ACTION" != "update" ]; then
        log_error "Directory input is only supported for create/update actions"
        log_error "Provided: $input_path"
        exit 1
    fi

    DIR_INPUT=true
    DIR_INPUT_PATH="$input_path"

    log_info "Directory input detected: $input_path"

    # Collect .json files (non-recursive, sorted for deterministic order)
    local json_files=()
    while IFS= read -r -d '' f; do
        json_files+=("$f")
    done < <(find "$input_path" -maxdepth 1 -name '*.json' -type f -print0 | sort -z)

    if [ ${#json_files[@]} -eq 0 ]; then
        log_error "No .json files found in directory: $input_path"
        exit 1
    fi

    log_info "Found ${#json_files[@]} .json file(s) in directory"

    # Validate each file and merge into a single JSON array
    DIR_MERGED_TMPFILE=$(mktemp --suffix=.json)
    echo '[]' > "$DIR_MERGED_TMPFILE"

    local file_count=0
    for json_file in "${json_files[@]}"; do
        local basename_f
        basename_f=$(basename "$json_file")

        # Validate JSON syntax
        if ! jq empty "$json_file" 2>/dev/null; then
            log_error "Invalid JSON in file: $basename_f -- skipping"
            continue
        fi

        # Must be an array
        if ! jq -e 'type == "array"' "$json_file" >/dev/null 2>&1; then
            log_error "File is not a JSON array: $basename_f -- skipping"
            continue
        fi

        local job_count
        job_count=$(jq 'length' "$json_file")
        log_step "  $basename_f ($job_count job(s))"

        # Merge into accumulator
        DIR_MERGED_TMPFILE_NEW=$(mktemp --suffix=.json)
        jq -s '.[0] + .[1]' "$DIR_MERGED_TMPFILE" "$json_file" > "$DIR_MERGED_TMPFILE_NEW"
        mv "$DIR_MERGED_TMPFILE_NEW" "$DIR_MERGED_TMPFILE"

        file_count=$((file_count + 1))
    done

    if [ $file_count -eq 0 ]; then
        log_error "No valid .json files found in directory: $input_path"
        rm -f "$DIR_MERGED_TMPFILE"
        exit 1
    fi

    local total_merged
    total_merged=$(jq 'length' "$DIR_MERGED_TMPFILE")
    log_success "Merged $total_merged job(s) from $file_count file(s)"

    # Point JOBS_FILE to the merged temp file
    JOBS_FILE="$DIR_MERGED_TMPFILE"
}

################################################################################
# Function: cleanup_dir_input
# Description: Remove the temporary merged JSON file created by
#              resolve_directory_input, if applicable.
################################################################################
cleanup_dir_input() {
    if [ "$DIR_INPUT" = true ] && [ -n "$DIR_MERGED_TMPFILE" ] && [ -f "$DIR_MERGED_TMPFILE" ]; then
        rm -f "$DIR_MERGED_TMPFILE"
    fi
}

################################################################################
# Function: validate_input_file
# Description: Validate input file exists and has correct format for action
################################################################################
validate_input_file() {
    if [ ! -f "$JOBS_FILE" ]; then
        log_error "Input file not found: $JOBS_FILE"
        exit 1
    fi
    
    # Check file extension
    local file_ext="${JOBS_FILE##*.}"
    
    case "$ACTION" in
        create|update)
            # Must be JSON file
            if [ "$file_ext" != "json" ]; then
                log_error "For $ACTION action, input file must be JSON format"
                exit 1
            fi
            
            # Validate JSON syntax
            if ! jq empty "$JOBS_FILE" 2>/dev/null; then
                log_error "Invalid JSON format in file: $JOBS_FILE"
                exit 1
            fi
            
            # Check if it's an array
            if ! jq -e 'type == "array"' "$JOBS_FILE" >/dev/null 2>&1; then
                log_error "JSON file must contain an array of jobs"
                exit 1
            fi
            ;;
            
        stop|delete|status|export)
            # Can be JSON or TXT
            if [ "$file_ext" = "json" ]; then
                # Validate JSON syntax
                if ! jq empty "$JOBS_FILE" 2>/dev/null; then
                    log_error "Invalid JSON format in file: $JOBS_FILE"
                    exit 1
                fi
            elif [ "$file_ext" != "txt" ]; then
                log_error "For $ACTION action, input file must be JSON or TXT format"
                exit 1
            fi
            ;;
    esac
    
    log_success "Input file validated: $JOBS_FILE"
}

################################################################################
# Function: validate_log_path
# Description: Validate optional log file path parameter
################################################################################
validate_log_path() {
    local log_path="$1"
    
    if [ -z "$log_path" ]; then
        # No log path provided, use current directory
        LOG_DIR="."
        return 0
    fi
    
    # Check if path exists
    if [ ! -d "$log_path" ]; then
        log_error "Log directory does not exist: $log_path"
        exit 1
    fi
    
    # Check if path is writable
    if [ ! -w "$log_path" ]; then
        log_error "Log directory is not writable: $log_path"
        exit 1
    fi
    
    LOG_DIR="$log_path"
    log_success "Log directory validated: $LOG_DIR"
}

################################################################################
# Function: check_prerequisites
# Description: Verify required tools and cluster access
################################################################################
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if oc is installed
    if ! command -v oc &> /dev/null; then
        log_error "oc CLI is not installed. Please install OpenShift CLI."
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq for JSON processing."
        exit 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl."
        exit 1
    fi
    
    # Check if logged into OpenShift cluster
    if ! oc whoami &> /dev/null; then
        log_error "Not logged into OpenShift cluster. Please run 'oc login' first."
        exit 1
    fi
    
    # Get current namespace
    NAMESPACE=$(oc project -q 2>/dev/null)
    if [ -z "$NAMESPACE" ]; then
        log_error "Could not determine current namespace"
        exit 1
    fi
    
    log_success "All prerequisites met"
    log_info "Current namespace: $NAMESPACE"
}

################################################################################
# Function: get_credentials
# Description: Retrieve API credentials from OpenShift secret
################################################################################
get_credentials() {
    log_info "Retrieving API credentials..."
    
    # Get credentials from secret
    API_USERNAME=$(oc get secret -n "$NAMESPACE" aiops-topology-asm-credentials -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode)
    API_PASSWORD=$(oc get secret -n "$NAMESPACE" aiops-topology-asm-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode)
    
    if [ -z "$API_USERNAME" ] || [ -z "$API_PASSWORD" ]; then
        log_error "Failed to retrieve credentials from secret 'aiops-topology-asm-credentials'"
        log_error "Make sure the secret exists in namespace: $NAMESPACE"
        exit 1
    fi
    
    log_success "Credentials retrieved successfully"
}

################################################################################
# Function: discover_observer_route
# Description: Find the Cisco ACI observer route dynamically
################################################################################
discover_observer_route() {
    log_info "Discovering Cisco ACI observer route..."

    # Try OpenShift route first, fall back to ingress (Linux VM environments)
    OBSERVER_HOST=$(
        oc get route -n "$NAMESPACE" -o json 2>/dev/null \
            | jq -r '.items[] | select(.metadata.name | contains("ciscoaci")) | .spec.host // ""' \
            | head -n 1
    )

    if [ -z "$OBSERVER_HOST" ]; then
        log_info "No OpenShift route found for ciscoaci observer, trying ingress..."
        OBSERVER_HOST=$(
            oc get ingress aiops-topology-ciscoaci-observer-9112 \
                -n "$NAMESPACE" \
                -o jsonpath='{.spec.rules[0].host}' 2>/dev/null
        )
    fi

    if [ -z "$OBSERVER_HOST" ]; then
        log_error "Cisco ACI observer route/ingress not found"
        log_error "Please ensure observer routes or ingresses are enabled"
        exit 1
    fi

    # Extract path - check route first, then ingress
    OBSERVER_PATH=$(
        oc get route -n "$NAMESPACE" -o json 2>/dev/null \
            | jq -r '.items[] | select(.metadata.name | contains("ciscoaci")) | .spec.path // ""' \
            | head -n 1
    )

    if [ -z "$OBSERVER_PATH" ]; then
        OBSERVER_PATH=$(
            oc get ingress aiops-topology-ciscoaci-observer-9112 \
                -n "$NAMESPACE" \
                -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null
        )
    fi

    # Construct base URL
    if [ -n "$OBSERVER_PATH" ] && [ "$OBSERVER_PATH" != "/" ]; then
        OBSERVER_BASE_URL="https://${OBSERVER_HOST}${OBSERVER_PATH}"
    else
        OBSERVER_BASE_URL="https://${OBSERVER_HOST}"
    fi

    log_success "Observer endpoint discovered: $OBSERVER_BASE_URL"
}

################################################################################
# Function: discover_topology_route
# Description: Discover the topology API route
################################################################################
discover_topology_route() {
    log_info "Discovering topology route..."
    
    # Try OpenShift route first, fall back to ingress (Linux VM environments)
    TOPOLOGY_HOST=$(
        oc get route -n "$NAMESPACE" -o json 2>/dev/null \
            | jq -r '.items[] | select(.metadata.name | contains("topology-topology")) | .spec.host // ""' \
            | head -n 1
    )

    if [ -z "$TOPOLOGY_HOST" ]; then
        log_info "No OpenShift route found for topology, trying ingress..."
        TOPOLOGY_HOST=$(
            oc get ingress aiops-topology-topology-8080 \
                -n "$NAMESPACE" \
                -o jsonpath='{.spec.rules[0].host}' 2>/dev/null
        )
    fi

    if [ -z "$TOPOLOGY_HOST" ]; then
        log_error "Topology route/ingress not found"
        log_error "Please ensure topology routes or ingresses are enabled"
        exit 1
    fi

    # Construct base URL
    TOPOLOGY_BASE_URL="https://${TOPOLOGY_HOST}/1.0/topology"

    log_success "Topology endpoint discovered: $TOPOLOGY_BASE_URL"
}

################################################################################
# Function: setup_log_file
# Description: Setup log file with timestamp
################################################################################
setup_log_file() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/ciscoaci-job-${ACTION}-${timestamp}.log"
    log_success "Log file: $LOG_FILE"
}

################################################################################
# Function: display_failure_mode
# Description: Display the configured failure handling mode
################################################################################
display_failure_mode() {
    if [ "$CONTINUE_ON_FAILURE" = true ]; then
        log_info "Mode: Continue on failure"
    else
        log_info "Mode: Stop on first failure"
    fi
}

################################################################################
# Function: parse_job_list
# Description: Parse job list from JSON or TXT file
################################################################################
parse_job_list() {
    local file="$1"
    local file_ext="${file##*.}"
    
    JOB_IDS=()
    
    if [ "$file_ext" = "json" ]; then
        # Check if it's an array
        if jq -e 'type == "array"' "$file" > /dev/null 2>&1; then
            # Parse JSON array - extract unique_id from each object
            JOB_IDS=($(jq -r '.[].unique_id' "$file" 2>/dev/null))
        else
            log_error "JSON file must contain an array of job objects"
            exit 1
        fi
    else
        # Parse TXT file (one job per line, skip empty lines and comments)
        while IFS= read -r line; do
            JOB_IDS+=("$line")
        done < <(grep -v '^[[:space:]]*$' "$file" | grep -v '^#')
    fi
    
    TOTAL_JOBS=${#JOB_IDS[@]}
    
    if [ $TOTAL_JOBS -eq 0 ]; then
        log_error "No job IDs found in file '$file'"
        exit 1
    fi
    
    log_success "Found $TOTAL_JOBS job(s) to process"
}

################################################################################
# Password Encryption Functions
################################################################################

################################################################################
# Function: discover_topology_pod
# Description: Find a running topology-topology pod for password encryption
################################################################################
discover_topology_pod() {
    log_info "Discovering topology-topology pod for password encryption..."

    TOPOLOGY_POD=$(oc get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
        | grep 'topology-topology' \
        | grep 'Running' \
        | head -n 1 \
        | awk '{print $1}')

    if [ -z "$TOPOLOGY_POD" ]; then
        log_error "No running topology-topology pod found in namespace: $NAMESPACE"
        log_error "Password encryption requires a running topology-topology pod"
        exit 1
    fi

    log_success "Using topology pod: $TOPOLOGY_POD"
}

################################################################################
# Function: encrypt_password_in_pod
# Description: Encrypt a cleartext password using the topology pod JAR utility.
#              Uses 'oc exec' to run the encrypt_password command inside the pod.
#              The Java process emits ERROR lines to stdout (Cassandra SSL
#              warnings) which are filtered out; only the encrypted string is
#              returned.
# Arguments: $1 - cleartext password
# Returns:   Encrypted password string via stdout
################################################################################
encrypt_password_in_pod() {
    local cleartext="$1"

    if [ -z "$cleartext" ]; then
        log_error "Cannot encrypt empty password"
        return 1
    fi

    local encrypted
    encrypted=$(oc exec "$TOPOLOGY_POD" -n "$NAMESPACE" -- \
        java -jar /opt/ibm/topology-service/topology-service.jar \
        encrypt_password --password "$cleartext" 2>/dev/null \
        | grep -v '^ERROR' \
        | tail -1 \
        | tr -d '\r\n')

    if [ -z "$encrypted" ]; then
        log_error "Password encryption returned empty result"
        log_error "Verify the topology pod is healthy: $TOPOLOGY_POD"
        return 1
    fi

    echo "$encrypted"
}

################################################################################
# Function: prepare_encrypted_passwords
# Description: Encrypt APIC and/or truststore passwords if provided via flags.
#              Discovers a topology pod, runs encryption, and stores results in
#              ENCRYPTED_APIC_PASSWORD / ENCRYPTED_TRUSTSTORE_PASSWORD globals.
################################################################################
prepare_encrypted_passwords() {
    if [ -z "$APIC_PASSWORD" ] && [ -z "$TRUSTSTORE_PASSWORD" ]; then
        return 0
    fi

    # Discover topology pod for encryption
    discover_topology_pod

    # Encrypt APIC password if provided
    if [ -n "$APIC_PASSWORD" ]; then
        log_info "Encrypting APIC password via pod: $TOPOLOGY_POD ..."
        ENCRYPTED_APIC_PASSWORD=$(encrypt_password_in_pod "$APIC_PASSWORD")
        if [ $? -ne 0 ] || [ -z "$ENCRYPTED_APIC_PASSWORD" ]; then
            log_error "Failed to encrypt APIC password"
            exit 1
        fi
        log_success "APIC password encrypted successfully"
    fi

    # Encrypt truststore password if provided
    if [ -n "$TRUSTSTORE_PASSWORD" ]; then
        log_info "Encrypting SSL truststore password via pod: $TOPOLOGY_POD ..."
        ENCRYPTED_TRUSTSTORE_PASSWORD=$(encrypt_password_in_pod "$TRUSTSTORE_PASSWORD")
        if [ $? -ne 0 ] || [ -z "$ENCRYPTED_TRUSTSTORE_PASSWORD" ]; then
            log_error "Failed to encrypt truststore password"
            exit 1
        fi
        log_success "Truststore password encrypted successfully"
    fi
}

################################################################################
# Function: inject_encrypted_passwords
# Description: Inject encrypted passwords into a single job's JSON data.
#              Replaces parameters.ciscoapic_password and/or
#              parameters.password_ssl_truststore_file with the pre-encrypted
#              values when the corresponding flags were provided.
# Arguments:   $1 - compact JSON string for one job
# Returns:     Modified JSON string via stdout
################################################################################
inject_encrypted_passwords() {
    local job_data="$1"

    if [ -n "$ENCRYPTED_APIC_PASSWORD" ]; then
        job_data=$(echo "$job_data" | jq -c --arg pw "$ENCRYPTED_APIC_PASSWORD" \
            '.parameters.ciscoapic_password = $pw')
    fi

    if [ -n "$ENCRYPTED_TRUSTSTORE_PASSWORD" ]; then
        job_data=$(echo "$job_data" | jq -c --arg pw "$ENCRYPTED_TRUSTSTORE_PASSWORD" \
            '.parameters.password_ssl_truststore_file = $pw')
    fi

    echo "$job_data"
}

################################################################################
# CREATE/UPDATE ACTION FUNCTIONS
################################################################################

################################################################################
# Function: create_jobs
# Description: Create new observer jobs via REST API
################################################################################
create_jobs() {
    log_info "Starting job creation process..."
    
    # Initialize counters
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    ASYNC_COUNT=0
    SKIPPED_COUNT=0
    
    # Get total jobs
    TOTAL_JOBS=$(jq '. | length' "$JOBS_FILE")
    log_info "Total jobs to create: $TOTAL_JOBS"
    
    # Initialize log file with placeholder for summary
    {
        echo "=========================================="
        echo "Cisco ACI Observer Job Create Log"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Jobs File: $JOBS_FILE"
        echo "Total Jobs: $TOTAL_JOBS"
        echo "=========================================="
        echo ""
        echo "SUMMARY_PLACEHOLDER"
        echo ""
        echo "=========================================="
        echo "Detailed Job Results"
        echo "=========================================="
        echo ""
    } > "$LOG_FILE"
    
    # Process each job
    JOB_INDEX=0
    while [ $JOB_INDEX -lt "$TOTAL_JOBS" ]; do
        # Extract job details
        JOB_DATA=$(jq -c ".[$JOB_INDEX]" "$JOBS_FILE")
        JOB_ID=$(echo "$JOB_DATA" | jq -r '.unique_id')
        JOB_TYPE=$(echo "$JOB_DATA" | jq -r '.type')
        
        log_step "[$((JOB_INDEX + 1))/$TOTAL_JOBS] Creating job: $JOB_ID (type: $JOB_TYPE)"
        
        # Inject encrypted passwords if provided via --apic-password / --truststore-password
        JOB_DATA=$(inject_encrypted_passwords "$JOB_DATA")
        
        # Determine endpoint based on job type
        if [ "$JOB_TYPE" = "restapi" ]; then
            ENDPOINT="${OBSERVER_BASE_URL}/jobs/restapi"
        elif [ "$JOB_TYPE" = "websocket" ]; then
            ENDPOINT="${OBSERVER_BASE_URL}/jobs/websocket"
        else
            log_error "Invalid job type: $JOB_TYPE (must be 'restapi' or 'websocket')"
            {
                echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                echo "  Status: FAILED"
                echo "  Reason: Invalid job type '$JOB_TYPE'"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            JOB_INDEX=$((JOB_INDEX + 1))
            continue
        fi
        
        # Create temporary files for response and errors
        RESPONSE_FILE=$(mktemp)
        ERROR_FILE=$(mktemp)
        
        # Make API call with timeout
        HTTP_CODE=$(curl -ksX POST "$ENDPOINT" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -H "X-TenantID: $TENANT_ID" \
            -u "$API_USERNAME:$API_PASSWORD" \
            -d "$JOB_DATA" \
            --max-time 30 \
            -w "%{http_code}" \
            -o "$RESPONSE_FILE" 2>"$ERROR_FILE")
        
        CURL_EXIT_CODE=$?
        RESPONSE_BODY=$(cat "$RESPONSE_FILE" 2>/dev/null || echo "")
        ERROR_MESSAGE=$(cat "$ERROR_FILE" 2>/dev/null || echo "")
        
        # Handle response
        if [ $CURL_EXIT_CODE -ne 0 ] && [ $CURL_EXIT_CODE -ne 28 ]; then
            # Curl error
            if [ -n "$ERROR_MESSAGE" ]; then
                log_error "Connection error: $ERROR_MESSAGE"
            else
                log_error "Connection error (curl exit code: $CURL_EXIT_CODE)"
            fi
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$ERROR_MESSAGE" ] && echo "  Error: $ERROR_MESSAGE"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
            if [ "$CONTINUE_ON_FAILURE" = "false" ]; then
                log_error "Stopping job creation due to failure (stop-on-failure mode)"
                echo "" >> "$LOG_FILE"
                echo "Job creation stopped after failure. Remaining jobs were not processed." >> "$LOG_FILE"
                break
            fi
            
        elif [ $CURL_EXIT_CODE -eq 28 ] || [ "$HTTP_CODE" = "000" ]; then
            # Timeout
            log_warning "Timeout (job likely accepted and processing)"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: TIMEOUT (likely accepted)"
                echo "  Note: Job was likely accepted but response timed out"
                echo ""
            } >> "$LOG_FILE"
            ASYNC_COUNT=$((ASYNC_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            # Success
            log_success "Job created successfully: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: SUCCESS"
                echo ""
            } >> "$LOG_FILE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
        else
            # Other HTTP errors
            log_error "Failed with HTTP code: $HTTP_CODE"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
            if [ "$CONTINUE_ON_FAILURE" = "false" ]; then
                log_error "Stopping job creation due to failure (stop-on-failure mode)"
                echo "" >> "$LOG_FILE"
                echo "Job creation stopped after failure. Remaining jobs were not processed." >> "$LOG_FILE"
                break
            fi
        fi
        
        # Cleanup temp files
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        
        JOB_INDEX=$((JOB_INDEX + 1))
    done
    
    # Calculate skipped jobs
    SKIPPED_COUNT=$((TOTAL_JOBS - SUCCESS_COUNT - FAILED_COUNT - ASYNC_COUNT))
}

################################################################################
# Function: update_jobs
# Description: Update existing observer jobs via REST API with validation
################################################################################
update_jobs() {
    log_info "Starting job update process..."
    
    # Initialize counters
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    ASYNC_COUNT=0
    SKIPPED_COUNT=0
    
    # Get total jobs
    TOTAL_JOBS=$(jq '. | length' "$JOBS_FILE")
    log_info "Total jobs to update: $TOTAL_JOBS"
    
    # Initialize log file with placeholder for summary
    {
        echo "=========================================="
        echo "Cisco ACI Observer Job Update Log"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Jobs File: $JOBS_FILE"
        echo "Total Jobs: $TOTAL_JOBS"
        echo "=========================================="
        echo ""
        echo "SUMMARY_PLACEHOLDER"
        echo ""
        echo "=========================================="
        echo "Detailed Job Results"
        echo "=========================================="
        echo ""
    } > "$LOG_FILE"
    
    # Process each job
    JOB_INDEX=0
    while [ $JOB_INDEX -lt "$TOTAL_JOBS" ]; do
        # Extract job details
        JOB_DATA=$(jq -c ".[$JOB_INDEX]" "$JOBS_FILE")
        JOB_ID=$(echo "$JOB_DATA" | jq -r '.unique_id')
        JOB_TYPE=$(echo "$JOB_DATA" | jq -r '.type')
        
        log_step "[$((JOB_INDEX + 1))/$TOTAL_JOBS] Updating job: $JOB_ID (type: $JOB_TYPE)"
        
        # Inject encrypted passwords if provided via --apic-password / --truststore-password
        JOB_DATA=$(inject_encrypted_passwords "$JOB_DATA")
        
        # Validate job exists and is not running
        # Query topology to check if job exists
        QUERY_ENDPOINT="${TOPOLOGY_BASE_URL}/mgmt_artifacts"
            QUERY_PARAMS="?_filter=entityTypes%3DASM_OBSERVER_JOB&_filter=name%3A${JOB_ID}&_field=name&_field=hasState&_field=path&_include_count=false&_limit=1"
            
            QUERY_RESPONSE=$(mktemp)
            QUERY_ERROR=$(mktemp)
            
            HTTP_CODE=$(curl -ksS -w "%{http_code}" \
                -X GET \
                "${QUERY_ENDPOINT}${QUERY_PARAMS}" \
                -H "X-TenantID: ${TENANT_ID}" \
                -u "${API_USERNAME}:${API_PASSWORD}" \
                -o "$QUERY_RESPONSE" \
                2>"$QUERY_ERROR")
            
            if [ $? -ne 0 ] || [ "$HTTP_CODE" != "200" ]; then
                log_error "Failed to query topology API (HTTP: $HTTP_CODE)"
                {
                    echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                    echo "  Status: QUERY_FAILED"
                    echo "  Reason: Unable to query topology API. HTTP Code: $HTTP_CODE"
                    echo "  Details: Check API connectivity and credentials"
                    echo ""
                } >> "$LOG_FILE"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                rm -f "$QUERY_RESPONSE" "$QUERY_ERROR"
                
                if [ "$CONTINUE_ON_FAILURE" = false ]; then
                    log_error "Stopping due to job failure (CONTINUE_ON_FAILURE=false)"
                    break
                fi
                JOB_INDEX=$((JOB_INDEX + 1))
                continue
            fi
            
            # Parse response - same as delete function
            ITEMS_JSON=$(jq -r '._items' "$QUERY_RESPONSE" 2>/dev/null)
            EXISTING_JOB=$(echo "$ITEMS_JSON" | jq -r '.[0] // empty' 2>/dev/null)
            
            if [ -z "$EXISTING_JOB" ] || [ "$EXISTING_JOB" = "null" ]; then
                log_error "Cannot find job: '$JOB_ID' in topology"
                {
                    echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                    echo "  Status: NOT_FOUND"
                    echo "  Reason: Job with unique_id '$JOB_ID' does not exist in topology"
                    echo "  Action: Use 'create' action to create this job first"
                    echo ""
                } >> "$LOG_FILE"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                rm -f "$QUERY_RESPONSE" "$QUERY_ERROR"
                
                if [ "$CONTINUE_ON_FAILURE" = false ]; then
                    log_error "Stopping due to failure (CONTINUE_ON_FAILURE=false)"
                    break
                fi
                JOB_INDEX=$((JOB_INDEX + 1))
                continue
            fi
            
            # Check if job is running
            EXISTING_STATE=$(echo "$EXISTING_JOB" | jq -r '.hasState // "FINISHED"')
            if [ "$EXISTING_STATE" = "RUNNING" ]; then
                log_error "Cannot update running job: $JOB_ID"
                {
                    echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                    echo "  Status: RUNNING"
                    echo "  Reason: Cannot update job while it is running. Stop the job first before updating."
                    echo ""
                } >> "$LOG_FILE"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                rm -f "$QUERY_RESPONSE" "$QUERY_ERROR"
                
                if [ "$CONTINUE_ON_FAILURE" = false ]; then
                    log_error "Stopping due to failure (CONTINUE_ON_FAILURE=false)"
                    break
                fi
                JOB_INDEX=$((JOB_INDEX + 1))
                continue
            fi
            
            # Check if job type matches by comparing path
            # Topology stores: "/jobs/restapi" or "/jobs/websocket"
            EXISTING_PATH=$(echo "$EXISTING_JOB" | jq -r '.path // ""')
            EXPECTED_PATH="/jobs/${JOB_TYPE}"
            
            if [ -n "$EXISTING_PATH" ] && [ "$EXISTING_PATH" != "$EXPECTED_PATH" ]; then
                # Extract type from path for error message
                EXISTING_TYPE=$(echo "$EXISTING_PATH" | sed 's|/jobs/||')
                log_error "Job type mismatch for: $JOB_ID (existing: '$EXISTING_TYPE', requested: '$JOB_TYPE')"
                {
                    echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                    echo "  Status: TYPE_MISMATCH"
                    echo "  Reason: Cannot change job type from '$EXISTING_TYPE' to '$JOB_TYPE'. Job type cannot be modified."
                    echo ""
                } >> "$LOG_FILE"
                FAILED_COUNT=$((FAILED_COUNT + 1))
                rm -f "$QUERY_RESPONSE" "$QUERY_ERROR"
                
                if [ "$CONTINUE_ON_FAILURE" = false ]; then
                    log_error "Stopping due to failure (CONTINUE_ON_FAILURE=false)"
                    break
                fi
                JOB_INDEX=$((JOB_INDEX + 1))
                continue
            fi
            
        rm -f "$QUERY_RESPONSE" "$QUERY_ERROR"
        log_info "Job validation passed, proceeding with update"
        
        # Determine endpoint based on job type
        if [ "$JOB_TYPE" = "restapi" ]; then
            ENDPOINT="${OBSERVER_BASE_URL}/jobs/restapi"
        elif [ "$JOB_TYPE" = "websocket" ]; then
            ENDPOINT="${OBSERVER_BASE_URL}/jobs/websocket"
        else
            log_error "Invalid job type: $JOB_TYPE (must be 'restapi' or 'websocket')"
            {
                echo "Job $((JOB_INDEX + 1)): $JOB_ID"
                echo "  Status: FAILED"
                echo "  Reason: Invalid job type '$JOB_TYPE'"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            JOB_INDEX=$((JOB_INDEX + 1))
            continue
        fi
        
        # Create temporary files for response and errors
        RESPONSE_FILE=$(mktemp)
        ERROR_FILE=$(mktemp)
        
        # Make API call with timeout
        HTTP_CODE=$(curl -ksX POST "$ENDPOINT" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -H "X-TenantID: $TENANT_ID" \
            -u "$API_USERNAME:$API_PASSWORD" \
            -d "$JOB_DATA" \
            --max-time 30 \
            -w "%{http_code}" \
            -o "$RESPONSE_FILE" 2>"$ERROR_FILE")
        
        CURL_EXIT_CODE=$?
        RESPONSE_BODY=$(cat "$RESPONSE_FILE" 2>/dev/null || echo "")
        ERROR_MESSAGE=$(cat "$ERROR_FILE" 2>/dev/null || echo "")
        
        # Handle response
        if [ $CURL_EXIT_CODE -ne 0 ] && [ $CURL_EXIT_CODE -ne 28 ]; then
            # Curl error
            if [ -n "$ERROR_MESSAGE" ]; then
                log_error "Connection error: $ERROR_MESSAGE"
            else
                log_error "Connection error (curl exit code: $CURL_EXIT_CODE)"
            fi
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$ERROR_MESSAGE" ] && echo "  Error: $ERROR_MESSAGE"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
            if [ "$CONTINUE_ON_FAILURE" = "false" ]; then
                log_error "Stopping job $action_lower due to failure (stop-on-failure mode)"
                echo "" >> "$LOG_FILE"
                echo "Job $action_lower stopped after failure. Remaining jobs were not processed." >> "$LOG_FILE"
                break
            fi
            
        elif [ $CURL_EXIT_CODE -eq 28 ] || [ "$HTTP_CODE" = "000" ]; then
            # Timeout
            log_warning "Timeout (job likely accepted and processing)"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: TIMEOUT (likely accepted)"
                echo "  Note: Job was likely accepted but response timed out"
                echo ""
            } >> "$LOG_FILE"
            ASYNC_COUNT=$((ASYNC_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
            # Success
            log_success "Job ${action_past} successfully: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: SUCCESS"
                echo ""
            } >> "$LOG_FILE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
        else
            # Other HTTP errors
            log_error "Failed with HTTP code: $HTTP_CODE"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
            if [ "$CONTINUE_ON_FAILURE" = "false" ]; then
                log_error "Stopping job $action_lower due to failure (stop-on-failure mode)"
                echo "" >> "$LOG_FILE"
                echo "Job $action_lower stopped after failure. Remaining jobs were not processed." >> "$LOG_FILE"
                break
            fi
        fi
        
        # Cleanup temp files
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        
        JOB_INDEX=$((JOB_INDEX + 1))
    done
    
    # Calculate skipped jobs
    SKIPPED_COUNT=$((TOTAL_JOBS - SUCCESS_COUNT - FAILED_COUNT - ASYNC_COUNT))
}

################################################################################
# STOP ACTION FUNCTIONS
################################################################################

################################################################################
# Function: stop_jobs
# Description: Stop jobs via DELETE API
################################################################################
stop_jobs() {
    log_info "Starting job stop process..."
    
    # Initialize counters
    SUCCESS_COUNT=0
    FAILED_COUNT=0
    NOT_FOUND_COUNT=0
    
    # Parse job list
    parse_job_list "$JOBS_FILE"
    
    # Initialize log file
    {
        echo "=========================================="
        echo "Cisco ACI Observer Job Stop Log"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Jobs File: $JOBS_FILE"
        echo "Total Jobs: $TOTAL_JOBS"
        echo "=========================================="
        echo ""
        echo "SUMMARY_PLACEHOLDER"
        echo ""
        echo "=========================================="
        echo "Detailed Job Results"
        echo "=========================================="
        echo ""
    } > "$LOG_FILE"
    
    # Process each job
    for i in "${!JOB_IDS[@]}"; do
        JOB_ID="${JOB_IDS[$i]}"
        log_step "[$((i + 1))/$TOTAL_JOBS] Stopping job: $JOB_ID"
        
        # Create temporary files
        RESPONSE_FILE=$(mktemp)
        ERROR_FILE=$(mktemp)
        
        # Make DELETE API call
        HTTP_CODE=$(curl -ksX DELETE \
            "${OBSERVER_BASE_URL}/jobs/${JOB_ID}" \
            -H "X-TenantID: $TENANT_ID" \
            -u "$API_USERNAME:$API_PASSWORD" \
            --max-time 30 \
            -w "%{http_code}" \
            -o "$RESPONSE_FILE" 2>"$ERROR_FILE")
        
        CURL_EXIT_CODE=$?
        ERROR_MESSAGE=$(cat "$ERROR_FILE" 2>/dev/null || echo "")
        
        # Handle response
        if [ $CURL_EXIT_CODE -ne 0 ]; then
            log_error "Connection error"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$ERROR_MESSAGE" ] && echo "  Error: $ERROR_MESSAGE"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
            log_success "Job stopped successfully: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: SUCCESS"
                echo ""
            } >> "$LOG_FILE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "404" ]; then
            log_warning "Job not found or not running: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: NOT FOUND"
                echo "  Reason: Job does not exist or is not currently running"
                echo ""
            } >> "$LOG_FILE"
            NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
            
        else
            log_error "Failed with HTTP code: $HTTP_CODE"
            RESPONSE_BODY=$(cat "$RESPONSE_FILE" 2>/dev/null || echo "")
            {
                echo "Job: $JOB_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
    done
}

################################################################################
# DELETE ACTION FUNCTIONS
################################################################################

################################################################################
# Function: query_management_artifacts
# Description: Query topology API to get management artifact IDs for job names
################################################################################
query_management_artifacts() {
    log_info "Querying management artifacts for job names..."
    
    # Build comma-separated list of job names for filter
    JOB_NAMES_FILTER=$(IFS=,; echo "${JOB_IDS[*]}")
    
    # Construct query endpoint with filters
    QUERY_ENDPOINT="${TOPOLOGY_BASE_URL}/mgmt_artifacts"
    QUERY_PARAMS="?_filter=entityTypes%3DASM_OBSERVER_JOB&_filter=name%3A${JOB_NAMES_FILTER}&_field=name&_field=hasState&_include_count=false&_limit=500"
    
    # Create temporary files
    RESPONSE_FILE=$(mktemp)
    ERROR_FILE=$(mktemp)
    
    # Make API call
    HTTP_CODE=$(curl -ksS -w "%{http_code}" \
        -X GET \
        "${QUERY_ENDPOINT}${QUERY_PARAMS}" \
        -H "X-TenantID: ${TENANT_ID}" \
        -u "${API_USERNAME}:${API_PASSWORD}" \
        -o "$RESPONSE_FILE" \
        2>"$ERROR_FILE")
    
    CURL_EXIT_CODE=$?
    
    # Check for errors
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_error "Failed to query management artifacts"
        log_error "Curl error: $(cat "$ERROR_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Query failed with HTTP code: $HTTP_CODE"
        log_error "Response: $(cat "$RESPONSE_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    # Parse response
    ITEMS_JSON=$(jq -r '._items' "$RESPONSE_FILE" 2>/dev/null)
    ITEMS_COUNT=$(echo "$ITEMS_JSON" | jq 'length' 2>/dev/null)
    
    if [ -z "$ITEMS_COUNT" ] || [ "$ITEMS_COUNT" == "null" ]; then
        log_error "Failed to parse query response"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    # If no jobs found, return 0 count - will be handled in delete_jobs()
    
    log_success "Found $ITEMS_COUNT job(s) eligible for deletion"
    
    # Store the items for processing
    echo "$ITEMS_JSON" > "$RESPONSE_FILE"
    rm -f "$ERROR_FILE"
}

################################################################################
# Function: delete_jobs
# Description: Delete jobs via DELETE API using management artifact IDs
################################################################################
delete_jobs() {
    log_info "Starting job deletion process..."
    
    # Initialize counters
    SUCCESS_COUNT=0
    NOT_FOUND_COUNT=0
    RUNNING_COUNT=0
    FAILED_COUNT=0
    
    # Parse job list
    parse_job_list "$JOBS_FILE"
    
    # Query management artifacts
    query_management_artifacts
    
    # Read items from query response
    ITEMS_JSON=$(cat "$RESPONSE_FILE")
    ITEMS_COUNT=$(echo "$ITEMS_JSON" | jq 'length')
    
    # Initialize log file
    {
        echo "=========================================="
        echo "Cisco ACI Observer Job Delete Log"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Jobs File: $JOBS_FILE"
        echo "Total Jobs Requested: $TOTAL_JOBS"
        echo "Jobs Found for Deletion: $ITEMS_COUNT"
        echo "=========================================="
        echo ""
        echo "SUMMARY_PLACEHOLDER"
        echo ""
        echo "=========================================="
        echo "Detailed Job Results"
        echo "=========================================="
        echo ""
    } > "$LOG_FILE"
    
    # Process each requested job
    JOB_INDEX=0
    for JOB_ID in "${JOB_IDS[@]}"; do
        JOB_INDEX=$((JOB_INDEX + 1))
        log_step "[$JOB_INDEX/$TOTAL_JOBS] Processing job: $JOB_ID"
        
        # Find job in query results
        ITEM=$(echo "$ITEMS_JSON" | jq -c ".[] | select(.name == \"$JOB_ID\")")
        
        if [ -z "$ITEM" ] || [ "$ITEM" = "null" ]; then
            # Job not found in query results
            log_warning "Job not found: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  Status: NOT_FOUND"
                echo "  Reason: Job does not exist in topology"
                echo ""
            } >> "$LOG_FILE"
            NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
            continue
        fi
        
        # Check if job is running
        JOB_STATE=$(echo "$ITEM" | jq -r '.hasState // "FINISHED"')
        
        if [ "$JOB_STATE" = "RUNNING" ]; then
            # Job is running, cannot delete
            log_warning "Cannot delete running job: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  Status: RUNNING"
                echo "  Reason: Cannot delete job while it is running. Stop the job first before deletion."
                echo ""
            } >> "$LOG_FILE"
            RUNNING_COUNT=$((RUNNING_COUNT + 1))
            continue
        fi
        
        # Job can be deleted
        MGMT_ID=$(echo "$ITEM" | jq -r '._id')
        log_step "Deleting job: $JOB_ID"
        
        # Create temporary files
        DEL_RESPONSE_FILE=$(mktemp)
        DEL_ERROR_FILE=$(mktemp)
        
        # Make DELETE API call
        HTTP_CODE=$(curl -ksS -w "%{http_code}" \
            -X DELETE \
            "${TOPOLOGY_BASE_URL}/mgmt_artifacts/${MGMT_ID}" \
            -H "X-TenantID: ${TENANT_ID}" \
            -u "${API_USERNAME}:${API_PASSWORD}" \
            -o "$DEL_RESPONSE_FILE" \
            2>"$DEL_ERROR_FILE")
        
        CURL_EXIT_CODE=$?
        
        # Handle response
        if [ $CURL_EXIT_CODE -ne 0 ]; then
            log_error "Connection error"
            {
                echo "Job: $JOB_ID"
                echo "  Management ID: $MGMT_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                echo "  Error: $(cat "$DEL_ERROR_FILE")"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "204" ]; then
            log_success "Job deleted successfully: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  Management ID: $MGMT_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: DELETED"
                echo ""
            } >> "$LOG_FILE"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
        elif [ "$HTTP_CODE" = "404" ]; then
            log_warning "Job not found during deletion: $JOB_ID"
            {
                echo "Job: $JOB_ID"
                echo "  Management ID: $MGMT_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: NOT_FOUND"
                echo "  Reason: Job was found in query but not found during deletion"
                echo ""
            } >> "$LOG_FILE"
            NOT_FOUND_COUNT=$((NOT_FOUND_COUNT + 1))
            
        else
            log_error "Failed with HTTP code: $HTTP_CODE"
            RESPONSE_BODY=$(cat "$DEL_RESPONSE_FILE" 2>/dev/null || echo "")
            {
                echo "Job: $JOB_ID"
                echo "  Management ID: $MGMT_ID"
                echo "  HTTP Code: $HTTP_CODE"
                echo "  Status: FAILED"
                [ -n "$RESPONSE_BODY" ] && echo "  Response: $RESPONSE_BODY"
                echo ""
            } >> "$LOG_FILE"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
        
        rm -f "$DEL_RESPONSE_FILE" "$DEL_ERROR_FILE"
    done
    
    rm -f "$RESPONSE_FILE"
}

################################################################################
# STATUS ACTION FUNCTIONS
################################################################################

################################################################################
# Function: query_job_status
# Description: Query job status from topology API
################################################################################
query_job_status() {
    log_info "Querying job status from topology..."
    
    # Parse job list
    parse_job_list "$JOBS_FILE"
    
    # Build comma-separated list of job names for filter
    JOB_NAMES_FILTER=$(IFS=,; echo "${JOB_IDS[*]}")
    
    # Construct query endpoint with filters
    QUERY_ENDPOINT="${TOPOLOGY_BASE_URL}/mgmt_artifacts"
    QUERY_PARAMS="?_filter=entityTypes%3DASM_OBSERVER_JOB&_filter=name%3A${JOB_NAMES_FILTER}&_field=name&_field=hasState&_include_count=false&_limit=500"
    
    # Create temporary files
    RESPONSE_FILE=$(mktemp)
    ERROR_FILE=$(mktemp)
    
    # Make API call
    HTTP_CODE=$(curl -ksS -w "%{http_code}" \
        -X GET \
        "${QUERY_ENDPOINT}${QUERY_PARAMS}" \
        -H "X-TenantID: ${TENANT_ID}" \
        -u "${API_USERNAME}:${API_PASSWORD}" \
        -o "$RESPONSE_FILE" \
        2>"$ERROR_FILE")
    
    CURL_EXIT_CODE=$?
    
    # Check for errors
    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_error "Failed to query job status"
        log_error "Curl error: $(cat "$ERROR_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Query failed with HTTP code: $HTTP_CODE"
        log_error "Response: $(cat "$RESPONSE_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    # Parse response
    ITEMS_JSON=$(jq -r '._items' "$RESPONSE_FILE" 2>/dev/null)
    ITEMS_COUNT=$(echo "$ITEMS_JSON" | jq 'length' 2>/dev/null)
    
    if [ -z "$ITEMS_COUNT" ] || [ "$ITEMS_COUNT" == "null" ]; then
        log_error "Failed to parse query response"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi
    
    if [ "$ITEMS_COUNT" -eq 0 ]; then
        log_warning "No jobs found in topology"
        {
            echo "=========================================="
            echo "Cisco ACI Observer Job Status Log"
            echo "=========================================="
            echo "Timestamp: $(date)"
            echo "Jobs File: $JOBS_FILE"
            echo "Total Jobs Requested: $TOTAL_JOBS"
            echo "=========================================="
            echo ""
            echo "No jobs found in topology"
            echo ""
        } > "$LOG_FILE"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        return
    fi
    
    log_success "Found $ITEMS_COUNT job(s) in topology"
    
    # Initialize log file
    {
        echo "=========================================="
        echo "Cisco ACI Observer Job Status Log"
        echo "=========================================="
        echo "Timestamp: $(date)"
        echo "Jobs File: $JOBS_FILE"
        echo "Total Jobs Requested: $TOTAL_JOBS"
        echo "Jobs Found: $ITEMS_COUNT"
        echo "=========================================="
        echo ""
        echo "SUMMARY_PLACEHOLDER"
        echo ""
        echo "=========================================="
        echo "Job Status Details"
        echo "=========================================="
        echo ""
    } > "$LOG_FILE"
    
    # Count jobs by state
    declare -A STATE_COUNTS
    
    # Process each item
    ITEM_INDEX=0
    while [ $ITEM_INDEX -lt "$ITEMS_COUNT" ]; do
        ITEM=$(echo "$ITEMS_JSON" | jq -c ".[$ITEM_INDEX]")
        JOB_NAME=$(echo "$ITEM" | jq -r '.name')
        JOB_STATE=$(echo "$ITEM" | jq -r '.hasState // "FINISHED"')
        
        # Count by state
        STATE_COUNTS[$JOB_STATE]=$((${STATE_COUNTS[$JOB_STATE]:-0} + 1))
        
        log_info "Job: $JOB_NAME - State: $JOB_STATE"
        {
            echo "Job: $JOB_NAME"
            echo "  State: $JOB_STATE"
            echo ""
        } >> "$LOG_FILE"
        
        ITEM_INDEX=$((ITEM_INDEX + 1))
    done
    
    # Generate status summary
    echo "" >> "$LOG_FILE"
    echo "=========================================="  >> "$LOG_FILE"
    echo "Status Summary by State" >> "$LOG_FILE"
    echo "==========================================" >> "$LOG_FILE"
    
    for state in "${!STATE_COUNTS[@]}"; do
        echo "  $state: ${STATE_COUNTS[$state]}" >> "$LOG_FILE"
    done
    
    echo "==========================================" >> "$LOG_FILE"
    
    # Replace placeholder with summary
    SUMMARY_TEXT="Status Summary:\n"
    SUMMARY_TEXT+="  Total Jobs Requested: $TOTAL_JOBS\n"
    SUMMARY_TEXT+="  Jobs Found: $ITEMS_COUNT\n"
    SUMMARY_TEXT+="  Jobs Not Found: $((TOTAL_JOBS - ITEMS_COUNT))\n"
    SUMMARY_TEXT+="\nBreakdown by State:\n"
    for state in "${!STATE_COUNTS[@]}"; do
        SUMMARY_TEXT+="  $state: ${STATE_COUNTS[$state]}\n"
    done
    
    sed -i.bak "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE" 2>/dev/null || \
        perl -i.bak -pe "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE"
    rm -f "${LOG_FILE}.bak"
    
    # Display summary
    echo ""
    log_info "=========================================="
    log_info "Status Summary"
    log_info "=========================================="
    log_info "Total Jobs Requested: $TOTAL_JOBS"
    log_info "Jobs Found: $ITEMS_COUNT"
    log_info "Jobs Not Found: $((TOTAL_JOBS - ITEMS_COUNT))"
    echo ""
    log_info "Breakdown by State:"
    for state in "${!STATE_COUNTS[@]}"; do
        log_info "  $state: ${STATE_COUNTS[$state]}"
    done
    log_info "=========================================="
    
    rm -f "$RESPONSE_FILE" "$ERROR_FILE"
}

################################################################################
# EXPORT ACTION FUNCTIONS
################################################################################

################################################################################
# Function: export_jobs
# Description: Export full job definitions from topology to a JSON file
################################################################################
export_jobs() {
    log_info "Starting global job export process..."

    if [ "$INCLUDE_SECRETS" = true ]; then
        log_warning "Including encrypted password fields in export (--include-secrets)"
    fi

    # Step 1: Query all ASM_OBSERVER_JOB IDs from mgmt_artifacts
    QUERY_ENDPOINT="${TOPOLOGY_BASE_URL}/mgmt_artifacts"
    QUERY_PARAMS="?_filter=entityTypes%3DASM_OBSERVER_JOB&_field=_id&_include_count=false&_limit=500"

    # Create temporary files
    RESPONSE_FILE=$(mktemp)
    ERROR_FILE=$(mktemp)

    HTTP_CODE=$(curl -ksS -w "%{http_code}" \
        -X GET \
        "${QUERY_ENDPOINT}${QUERY_PARAMS}" \
        -H "X-TenantID: ${TENANT_ID}" \
        -u "${API_USERNAME}:${API_PASSWORD}" \
        -o "$RESPONSE_FILE" \
        2>"$ERROR_FILE")

    CURL_EXIT_CODE=$?

    if [ $CURL_EXIT_CODE -ne 0 ]; then
        log_error "Failed to query jobs for export"
        log_error "Curl error: $(cat "$ERROR_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi

    if [ "$HTTP_CODE" != "200" ]; then
        log_error "Query failed with HTTP code: $HTTP_CODE"
        log_error "Response: $(cat "$RESPONSE_FILE")"
        rm -f "$RESPONSE_FILE" "$ERROR_FILE"
        exit 1
    fi

    # Extract the list of IDs
    ITEMS_COUNT=$(jq -r '._items | length' "$RESPONSE_FILE" 2>/dev/null)
    IDS_ARRAY=($(jq -r '._items[]._id' "$RESPONSE_FILE" 2>/dev/null))

    rm -f "$RESPONSE_FILE" "$ERROR_FILE"

    if [ -z "$ITEMS_COUNT" ] || [ "$ITEMS_COUNT" = "null" ] || [ "$ITEMS_COUNT" -eq 0 ]; then
        log_warning "No jobs found in topology"
        EXPORT_FILE="${LOG_DIR}/exported-ciscoaci-jobs-$(date +"%Y%m%d_%H%M%S").json"
        echo "[]" > "$EXPORT_FILE"
        SUCCESS_COUNT=0
        TOTAL_JOBS=0
        return
    fi

    log_info "Found $ITEMS_COUNT job(s) - fetching full definitions..."

    # Determine output mode:
    # - LOG_DIR="." (default) -> single combined file
    # - LOG_DIR explicitly set -> per-job files in a timestamped subdirectory
    SPLIT_MODE=false
    EXPORT_SUBDIR=""
    if [ "$LOG_DIR" != "." ]; then
        SPLIT_MODE=true
        EXPORT_SUBDIR="${LOG_DIR}/export-$(date +"%Y%m%d_%H%M%S")"
        mkdir -p "$EXPORT_SUBDIR"
        log_info "Per-job export mode: writing individual files to $EXPORT_SUBDIR"
    fi

    # Step 2: Fetch each job individually and reshape to import format
    FULL_JOBS="[]"
    FETCH_SUCCESS=0
    FETCH_FAILED=0

    for MGMT_ID in "${IDS_ARRAY[@]}"; do
        ITEM_FILE=$(mktemp)
        ITEM_ERR=$(mktemp)

        ITEM_CODE=$(curl -ksS -w "%{http_code}" \
            -X GET \
            "${TOPOLOGY_BASE_URL}/mgmt_artifacts/${MGMT_ID}" \
            -H "X-TenantID: ${TENANT_ID}" \
            -u "${API_USERNAME}:${API_PASSWORD}" \
            -o "$ITEM_FILE" \
            2>"$ITEM_ERR")

        if [ "$ITEM_CODE" = "200" ]; then
            # Reshape to import schema:
            #   unique_id   <- .name
            #   type        <- .path stripped of "/jobs/" prefix (restapi|websocket)
            #   description <- .description (default "")
            #   parameters  <- .parameters
            #
            # Encrypted blobs ({hiddenString, encrypted:true}) are stored by the
            # topology service for credential fields (ciscoapic_password,
            # password_ssl_truststore_file).  These cannot be re-posted to the
            # observer as-is - it expects plaintext strings.
            #
            # Default:            encrypted fields are blanked to ""
            # --include-secrets:  the encrypted hiddenString value is preserved
            RESHAPED=$(INCLUDE_SECRETS="$INCLUDE_SECRETS" jq '{
                unique_id: .name,
                type: (.path // "" | ltrimstr("/jobs/")),
                description: (.description // ""),
                parameters: (
                    (.parameters // {}) |
                    with_entries(
                        if (.value | type) == "object" and .value.encrypted == true
                        then (
                            if env.INCLUDE_SECRETS == "true"
                            then .value = .value.hiddenString
                            else .value = ""
                            end
                        )
                        else .
                        end
                    )
                )
            }' "$ITEM_FILE" 2>/dev/null)

            JOB_NAME=$(echo "$RESHAPED" | jq -r '.unique_id')

            if [ "$SPLIT_MODE" = true ] && [ -n "$JOB_NAME" ] && [ "$JOB_NAME" != "null" ]; then
                # Write individual file as a single-element array (required by create/update)
                echo "[$RESHAPED]" | jq '.' > "${EXPORT_SUBDIR}/${JOB_NAME}.json"
                log_step "Exported: ${JOB_NAME}.json"
            fi

            FULL_JOBS=$(echo "$FULL_JOBS" | jq --argjson obj "$RESHAPED" '. + [$obj]')
            FETCH_SUCCESS=$((FETCH_SUCCESS + 1))
        else
            log_warning "Failed to fetch job $MGMT_ID (HTTP $ITEM_CODE)"
            FETCH_FAILED=$((FETCH_FAILED + 1))
        fi

        rm -f "$ITEM_FILE" "$ITEM_ERR"
    done

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

    if [ "$SPLIT_MODE" = true ]; then
        # Also write the combined file into the subdirectory
        EXPORT_FILE="${EXPORT_SUBDIR}/all-jobs-${TIMESTAMP}.json"
    else
        EXPORT_FILE="${LOG_DIR}/exported-ciscoaci-jobs-${TIMESTAMP}.json"
    fi

    echo "$FULL_JOBS" | jq '.' > "$EXPORT_FILE"

    SUCCESS_COUNT=$FETCH_SUCCESS
    TOTAL_JOBS=$ITEMS_COUNT

    if [ $FETCH_FAILED -gt 0 ]; then
        log_warning "$FETCH_FAILED job(s) could not be fetched individually"
    fi

    if [ "$SPLIT_MODE" = true ]; then
        log_success "Exported $FETCH_SUCCESS job(s) to: $EXPORT_SUBDIR"
    else
        log_success "Exported $FETCH_SUCCESS job(s) to: $EXPORT_FILE"
    fi
}

################################################################################
# Function: generate_summary_export
# Description: Generate summary for export action
################################################################################
generate_summary_export() {
    echo ""
    log_info "=========================================="
    log_info "Job Export Summary"
    log_info "=========================================="
    log_info "Total Jobs Found: $TOTAL_JOBS"
    log_info "Exported: $SUCCESS_COUNT"
    if [ -n "$EXPORT_SUBDIR" ]; then
        log_info "Output Directory: $EXPORT_SUBDIR"
        log_info "  Per-job files: <job_name>.json"
        log_info "  Combined file: $(basename "$EXPORT_FILE")"
    else
        log_info "Output File: $EXPORT_FILE"
    fi
    log_info "=========================================="

    if [ "$FETCH_FAILED" -gt 0 ]; then
        log_warning "$FETCH_FAILED job(s) could not be fetched and were excluded"
    fi
}

################################################################################
# SUMMARY AND EXIT FUNCTIONS
################################################################################

################################################################################
# Function: generate_summary_create_update
# Description: Generate summary for create/update actions
################################################################################
generate_summary_create_update() {
    local action_verb="$1"
    local action_word="$2"  # "create" or "update"
    
    echo ""
    log_info "=========================================="
    log_info "Job ${action_verb} Summary"
    log_info "=========================================="
    log_info "Total Jobs: $TOTAL_JOBS"
    log_info "Successful: $SUCCESS_COUNT"
    log_info "Failed: $FAILED_COUNT"
    log_info "Timeout (likely accepted): $ASYNC_COUNT"
    log_info "Skipped: $SKIPPED_COUNT"
    log_info "=========================================="
    
    # Generate summary text for log file
    SUMMARY_TEXT="Summary:\n"
    SUMMARY_TEXT+="  Total Jobs: $TOTAL_JOBS\n"
    SUMMARY_TEXT+="  Successful: $SUCCESS_COUNT\n"
    SUMMARY_TEXT+="  Failed: $FAILED_COUNT\n"
    SUMMARY_TEXT+="  Timeout (likely accepted): $ASYNC_COUNT\n"
    SUMMARY_TEXT+="  Skipped: $SKIPPED_COUNT"
    
    # Replace placeholder in log file
    sed -i.bak "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE" 2>/dev/null || \
        perl -i.bak -pe "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE"
    rm -f "${LOG_FILE}.bak"
    
    log_info "Summary added to log file: $LOG_FILE"
    
    # Provide recommendations
    if [ $ASYNC_COUNT -gt 0 ]; then
        log_warning "Some jobs timed out but were likely accepted"
        log_warning "Verify these jobs manually using the status action"
    fi
    
    if [ $FAILED_COUNT -gt 0 ]; then
        log_error "Some jobs failed to ${action_word}"
        log_error "Check the log file for details: $LOG_FILE"
    fi
}

################################################################################
# Function: generate_summary_stop
# Description: Generate summary for stop action
################################################################################
generate_summary_stop() {
    echo ""
    log_info "=========================================="
    log_info "Job Stop Summary"
    log_info "=========================================="
    log_info "Total Jobs: $TOTAL_JOBS"
    log_info "Stopped: $SUCCESS_COUNT"
    log_info "Not Found: $NOT_FOUND_COUNT"
    log_info "Failed: $FAILED_COUNT"
    log_info "=========================================="
    
    # Generate summary text for log file
    SUMMARY_TEXT="Summary:\n"
    SUMMARY_TEXT+="  Total Jobs: $TOTAL_JOBS\n"
    SUMMARY_TEXT+="  Stopped: $SUCCESS_COUNT\n"
    SUMMARY_TEXT+="  Not Found: $NOT_FOUND_COUNT\n"
    SUMMARY_TEXT+="  Failed: $FAILED_COUNT"
    
    # Replace placeholder in log file
    sed -i.bak "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE" 2>/dev/null || \
        perl -i.bak -pe "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE"
    rm -f "${LOG_FILE}.bak"
    
    log_info "Summary added to log file: $LOG_FILE"
    
    if [ $FAILED_COUNT -gt 0 ]; then
        log_error "Some jobs failed to stop"
        log_error "Check the log file for details: $LOG_FILE"
    fi
}

################################################################################
# Function: generate_summary_delete
# Description: Generate summary for delete action
################################################################################
generate_summary_delete() {
    echo ""
    log_info "=========================================="
    log_info "Job Delete Summary"
    log_info "=========================================="
    log_info "Total Jobs Requested: $TOTAL_JOBS"
    log_info "Deleted: $SUCCESS_COUNT"
    log_info "Not Found: $NOT_FOUND_COUNT"
    log_info "Cannot Delete: $RUNNING_COUNT"
    log_info "Failed: $FAILED_COUNT"
    log_info "=========================================="
    
    # Generate summary text for log file
    SUMMARY_TEXT="Summary:\n"
    SUMMARY_TEXT+="  Total Jobs Requested: $TOTAL_JOBS\n"
    SUMMARY_TEXT+="  Deleted: $SUCCESS_COUNT\n"
    SUMMARY_TEXT+="  Not Found: $NOT_FOUND_COUNT\n"
    SUMMARY_TEXT+="  Cannot Delete: $RUNNING_COUNT\n"
    SUMMARY_TEXT+="  Failed: $FAILED_COUNT"
    
    # Replace placeholder in log file
    sed -i.bak "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE" 2>/dev/null || \
        perl -i.bak -pe "s/SUMMARY_PLACEHOLDER/$SUMMARY_TEXT/" "$LOG_FILE"
    rm -f "${LOG_FILE}.bak"
    
    log_info "Summary added to log file: $LOG_FILE"
    
    if [ $RUNNING_COUNT -gt 0 ] && [ $NOT_FOUND_COUNT -gt 0 ]; then
        log_warning "Some jobs could not be deleted: $RUNNING_COUNT running, $NOT_FOUND_COUNT not found"
    elif [ $RUNNING_COUNT -gt 0 ]; then
        log_warning "Some jobs could not be deleted: $RUNNING_COUNT job(s) currently running"
    elif [ $NOT_FOUND_COUNT -gt 0 ]; then
        log_warning "Some jobs could not be deleted: $NOT_FOUND_COUNT job(s) not found in topology"
    fi
    
    if [ $FAILED_COUNT -gt 0 ]; then
        log_error "Some jobs failed to delete"
        log_error "Check the log file for details: $LOG_FILE"
    fi
}

################################################################################
# Function: determine_exit_code
# Description: Set appropriate exit code based on results and action
################################################################################
determine_exit_code() {
    case "$ACTION" in
        create|update)
            if [ $FAILED_COUNT -gt 0 ]; then
                exit 1
            elif [ $ASYNC_COUNT -eq $TOTAL_JOBS ]; then
                log_warning "All jobs timed out - verify manually"
                exit 2
            else
                log_success "All jobs processed successfully"
                exit 0
            fi
            ;;
        stop)
            if [ $FAILED_COUNT -gt 0 ]; then
                exit 1
            else
                log_success "All jobs processed successfully"
                exit 0
            fi
            ;;
        delete)
            if [ $FAILED_COUNT -gt 0 ]; then
                exit 1
            elif [ $RUNNING_COUNT -gt 0 ]; then
                log_warning "Some jobs are still running"
                exit 2
            else
                log_success "All jobs processed successfully"
                exit 0
            fi
            ;;
        status)
            log_success "Status query completed"
            exit 0
            ;;
        export)
            if [ -n "$EXPORT_SUBDIR" ]; then
                log_success "Export completed: $EXPORT_SUBDIR"
            else
                log_success "Export completed: $EXPORT_FILE"
            fi
            exit 0
            ;;
    esac
}

################################################################################
# MAIN EXECUTION
################################################################################

################################################################################
# Function: main
# Description: Main execution flow
################################################################################
main() {
    echo ""
    log_info "=========================================="
    log_info "Cisco ACI Observer Job Management Script"
    log_info "=========================================="
    echo ""

    # Parse named flags and collect positional arguments
    local positional_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --apic-password)
                if [ -z "${2:-}" ]; then
                    log_error "--apic-password requires a value"
                    display_usage
                    exit 1
                fi
                APIC_PASSWORD="$2"
                shift 2
                ;;
            --truststore-password)
                if [ -z "${2:-}" ]; then
                    log_error "--truststore-password requires a value"
                    display_usage
                    exit 1
                fi
                TRUSTSTORE_PASSWORD="$2"
                shift 2
                ;;
            --include-secrets)
                INCLUDE_SECRETS=true
                shift
                ;;
            -h|--help)
                display_usage
                exit 0
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done
    set -- "${positional_args[@]}"

    # Step 1: Validate parameters
    if [ $# -lt 1 ]; then
        log_error "Insufficient parameters"
        display_usage
        exit 1
    fi

    # Step 2: Validate action
    validate_action "$1"
    log_info "Action: $ACTION"

    # Step 2.5: Validate flag usage for the chosen action
    if [ -n "$APIC_PASSWORD" ] || [ -n "$TRUSTSTORE_PASSWORD" ]; then
        if [ "$ACTION" != "create" ] && [ "$ACTION" != "update" ]; then
            log_error "--apic-password / --truststore-password are only valid for create/update actions"
            display_usage
            exit 1
        fi
    fi
    if [ "$INCLUDE_SECRETS" = true ] && [ "$ACTION" != "export" ]; then
        log_error "--include-secrets is only valid for the export action"
        display_usage
        exit 1
    fi

    # Step 3: Set input file (not required for export)
    if [ "$ACTION" = "export" ]; then
        JOBS_FILE=""
        # For export, optional output path is $2 - create it if it doesn't exist
        if [ -n "${2:-}" ]; then
            mkdir -p "$2" 2>/dev/null || {
                log_error "Cannot create output directory: $2"
                exit 1
            }
            LOG_DIR="$2"
            log_info "Output directory: $LOG_DIR"
        else
            LOG_DIR="."
        fi
    else
        if [ $# -lt 2 ]; then
            log_error "Insufficient parameters: input-file is required for $ACTION"
            display_usage
            exit 1
        fi
        JOBS_FILE="$2"
        # Step 4: Validate log path (optional)
        validate_log_path "${3:-}"
    fi
    # Step 5: Check prerequisites
    check_prerequisites

    # Step 5.5: Resolve directory input (create/update only)
    if [ "$ACTION" != "export" ]; then
        resolve_directory_input "$JOBS_FILE"
    fi
    
    # Step 6: Validate input file (not applicable for export)
    if [ "$ACTION" != "export" ]; then
        validate_input_file
    fi
    
    # Step 7: Discover routes based on action
    case "$ACTION" in
        create|stop)
            discover_observer_route
            ;;
        update)
            # Update needs both routes: topology for validation, observer for update
            discover_topology_route
            discover_observer_route
            ;;
        delete|status|export)
            discover_topology_route
            ;;
    esac
    
    # Step 8: Get credentials
    get_credentials

    # Step 8.5: Encrypt passwords if --apic-password / --truststore-password provided
    if [ "$ACTION" = "create" ] || [ "$ACTION" = "update" ]; then
        prepare_encrypted_passwords
    fi
    
    # Step 9: Setup log file
    setup_log_file
    
    # Step 10: Display failure mode for create/update
    if [ "$ACTION" = "create" ] || [ "$ACTION" = "update" ]; then
        display_failure_mode
        echo ""
    fi
    
    # Step 11: Execute action
    case "$ACTION" in
        create)
            create_jobs
            generate_summary_create_update "Create" "create"
            ;;
        update)
            update_jobs
            generate_summary_create_update "Update" "update"
            ;;
        stop)
            stop_jobs
            generate_summary_stop
            ;;
        delete)
            delete_jobs
            generate_summary_delete
            ;;
        status)
            query_job_status
            ;;
        export)
            export_jobs
            generate_summary_export
            ;;
    esac

    # Step 12: Cleanup temporary files from directory input
    cleanup_dir_input

    # Step 13: Exit with appropriate code
    determine_exit_code
}

# Run main function
main "$@"