#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2020, 2023
# SPDX-License-Identifier: Apache2.0
#
# This script can be used to uninstall IBM Cloud Pak Foundational Services v3
# after upgrade to the Cloud Pak for AIOps 4.4.0.
#
# This script is a modified uninstall_tenant.sh from IBM Common Services GitHub at version
# https://github.com/IBM/ibm-common-service-operator/commit/567fef2e687e1c0ee56298a9b2c50b7fe9d1c0e1

# ---------- Command arguments ----------

# Default to using ibm-common-services namespace
OPERATOR_NS="ibm-common-services"

OC=oc
YQ=yq
TENANT_NAMESPACES=""
OPERATOR_NS_LIST=""
FORCE_DELETE=0
DEBUG=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# log file
LOG_FILE="uninstall_tenant_log_$(date +'%Y%m%d%H%M%S').log"

# ---------- Main functions ----------

function main() {
    parse_arguments "$@"
    save_log "logs" "uninstall_tenant_log" "$DEBUG"
    trap cleanup_log EXIT
    pre_req
    set_tenant_namespaces
    if [ $FORCE_DELETE -eq 0 ]; then
        uninstall_odlm
        uninstall_cs_operator
        uninstall_nss
    fi
    delete_rbac_resource
    delete_webhook
    delete_unavailable_apiservice
    delete_tenant_ns
}

function parse_arguments() {
    # process options
    while [[ "$@" != "" ]]; do
        case "$1" in
        --oc)
            shift
            OC=$1
            ;;
        --yq)
            shift
            YQ=$1
            ;;
        --operator-namespace)
            shift
            OPERATOR_NS=$1
            ;;
        -f)
            shift
            FORCE_DELETE=1
            ;;
        -v | --debug)
            shift
            DEBUG=$1
            ;;
        -h | --help)
            print_usage
            exit 1
            ;;
        *) 
            echo "wildcard"
            ;;
        esac
        shift
    done
}

function print_usage() {
    script_name=`basename ${0}`
    echo "Usage: ${script_name} --operator-namespace <bedrock-namespace> [OPTIONS]..."
    echo ""
    echo "Uninstall a tenant using Foundational services."
    echo "**NOTE**: this script will uninstall the entire tenant scoped to the Foundational services instance deployed in the namespace from the '--operator-namespace' parameter entered."
    echo "The default --operator-namespace is ibm-common-services. If this is not the correct namespace, the --operator-namespace must be provided."
    echo ""
    echo "Options:"
    echo "   --oc string                    Optional. File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                    Optional. File path to yq CLI. Default uses yq in your PATH"
    echo "   --operator-namespace string    Optional. Namespace to uninstall Foundational services operators and the whole tenant. Default is ibm-common-services."
    echo "   -f                             Optional. Enable force delete. It will take much more time if you add this label, we suggest run this script without -f label first"
    echo "   -v, --debug integer            Optional. Verbosity of logs. Default is 0. Set to 1 for debug logs"
    echo "   -h, --help                     Print usage information"
    echo ""
}

function pre_req() {
    # Check the value of DEBUG
    if [[ "$DEBUG" != "1" && "$DEBUG" != "0" ]]; then
        error "Invalid value for DEBUG. Expected 0 or 1."
    fi

    check_command "${OC}"
    check_command "${YQ}"
    check_yq_version

    # Checking oc command logged in
    user=$(${OC} whoami 2> /dev/null)
    if [ $? -ne 0 ]; then
        error "You must be logged into the OpenShift Cluster from the oc command line"
    else
        success "oc command logged in as ${user}"
    fi

    if [ "$OPERATOR_NS" == "" ]; then
        error "Must provide operator namespace"
    fi

    if [ $FORCE_DELETE -eq 1 ]; then
        warning "It will take much more time"
    fi
}

function set_tenant_namespaces() {
    # check if user want to cleanup operatorNamespace
    for ns in ${OPERATOR_NS//,/ }; do
        # if this namespace is operatorNamespace
        temp_namespace=$(${OC} get -n "$ns" configmap namespace-scope -o jsonpath='{.data.namespaces}' --ignore-not-found)
        if [ "$temp_namespace" != "" ]; then
            if [ "$TENANT_NAMESPACES" == "" ]; then
                TENANT_NAMESPACES=$temp_namespace
                OPERATOR_NS_LIST=$ns
            else
                TENANT_NAMESPACES="${TENANT_NAMESPACES},${temp_namespace}"
                OPERATOR_NS_LIST="${OPERATOR_NS_LIST},${ns}"
            fi
            continue
        fi

        # if this namespace is servicesNamespace
        operator_ns=$(${OC} get -n "$ns" commonservice common-service -o jsonpath='{.spec.operatorNamespace}' --ignore-not-found)
        services_ns=$(${OC} get -n "$ns" commonservice common-service -o jsonpath='{.spec.servicesNamespace}' --ignore-not-found)
        if [ "$services_ns" == "$ns" ]; then
            temp_namespace=$(${OC} get -n "$operator_ns" configmap namespace-scope -o jsonpath='{.data.namespaces}' --ignore-not-found)
            if [ "$TENANT_NAMESPACES" == "" ]; then
                TENANT_NAMESPACES=$temp_namespace
                OPERATOR_NS_LIST=$operator_ns
            else
                TENANT_NAMESPACES="${TENANT_NAMESPACES},${temp_namespace}"
                OPERATOR_NS_LIST="${OPERATOR_NS_LIST},${operator_ns}"
            fi
            continue
        fi

        # if this namespace neither operatorNamespace nor serviceNamsespace
        if [ "$TENANT_NAMESPACES" == "" ]; then
            TENANT_NAMESPACES=$ns
        else
            TENANT_NAMESPACES="${TENANT_NAMESPACES},${ns}"
        fi
    done

    # delete duplicate namespace in TENANT_NAMESPACES and OPERATOR_NS_LIST
    TENANT_NAMESPACES=$(echo "$TENANT_NAMESPACES" | sed -e 's/,/\n/g' | sort -u | tr "\r\n" "," | sed '$ s/,$//')
    OPERATOR_NS_LIST=$(echo "$OPERATOR_NS_LIST" | sed -e 's/,/\n/g' | sort -u | tr "\r\n" "," | sed '$ s/,$//')
    info "Tenant namespaces are: $TENANT_NAMESPACES"
}

function uninstall_odlm() {
    title "Uninstalling OperandRequests and ODLM"

    local grep_args=""
    for ns in ${TENANT_NAMESPACES//,/ }; do
        local opreq=$(${OC} get -n "$ns" operandrequests --no-headers | cut -d ' ' -f1)
        if [ "$opreq" != "" ]; then
            ${OC} delete -n "$ns" operandrequests ${opreq//$'\n'/ } --timeout=30s
        fi
        grep_args="${grep_args}-e $ns "
    done

    if [ "$grep_args" == "" ]; then
        grep_args='no-operand-requests'
    fi

    for ns in ${TENANT_NAMESPACES//,/ }; do
        local condition="${OC} get operandrequests -n ${ns} --no-headers | cut -d ' ' -f1 | grep -w ${grep_args} || echo Success"
        local retries=20
        local sleep_time=10
        local total_time_mins=$(( sleep_time * retries / 60))
        local wait_message="Waiting for all OperandRequests in tenant namespaces:${ns} to be deleted"
        local success_message="This tenant OperandRequests deleted"
        local error_message="Timeout after ${total_time_mins} minutes waiting for tenant OperandRequests to be deleted"

        # ideally ODLM will ensure OperandRequests are cleaned up neatly
        wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
    done

        for ns in ${TENANT_NAMESPACES//,/ }; do
        local sub=$(fetch_sub_from_package ibm-odlm $ns)
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi

        local csv=$(fetch_csv_from_sub operand-deployment-lifecycle-manager "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function uninstall_cs_operator() {
    title "Uninstalling ibm-common-service-operator in tenant namespaces"

    for ns in ${TENANT_NAMESPACES//,/ }; do
        local sub=$(fetch_sub_from_package ibm-common-service-operator $ns)
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi

        local csv=$(fetch_csv_from_sub "$sub" "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function uninstall_nss() {
    title "Uninstall ibm-namespace-scope-operator"

    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete --ignore-not-found nss -n "$ns" common-service --timeout=30s
        for op_ns in ${OPERATOR_NS_LIST//,/ }; do
            ${OC} delete --ignore-not-found rolebinding -n "$ns" "nss-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found role -n "$ns" "nss-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found rolebinding -n "$ns" "nss-runtime-managed-role-from-$op_ns"
            ${OC} delete --ignore-not-found role -n "$ns" "nss-runtime-managed-role-from-$op_ns"
        done

        sub=$(fetch_sub_from_package ibm-namespace-scope-operator "$ns")
        if [ "$sub" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" sub "$sub"
        fi
        csv=$(fetch_csv_from_sub "$sub" "$ns")
        if [ "$csv" != "" ]; then
            ${OC} delete --ignore-not-found -n "$ns" csv "$csv"
        fi
    done
}

function delete_webhook() {
    title "Deleting webhookconfigurations in ${TENANT_NAMESPACES}"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete ValidatingWebhookConfiguration ibm-common-service-validating-webhook-${ns} --ignore-not-found
        ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration ibm-operandrequest-webhook-configuration namespace-admission-config ibm-operandrequest-webhook-configuration-${ns} --ignore-not-found
    done
}

function delete_rbac_resource() {
    info "delete rbac resource"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete ClusterRoleBinding ibm-common-service-webhook secretshare-${ns} $(${OC} get ClusterRoleBinding | grep nginx-ingress-clusterrole | awk '{print $1}') --ignore-not-found
        ${OC} delete ClusterRole ibm-common-service-webhook secretshare nginx-ingress-clusterrole --ignore-not-found
        ${OC} delete scc nginx-ingress-scc --ignore-not-found
    done
}

function delete_unavailable_apiservice() {
    info "delete unavailable apiservice"
    rc=0
    apis=$(${OC} get apiservice | grep False | awk '{print $1}')
    if [ "X${apis}" != "X" ]; then
        warning "Found some unavailable apiservices, deleting ..."
        for api in ${apis}; do
        msg "${OC} delete apiservice ${api}"
        ${OC} delete apiservice ${api}
        if [[ "$?" != "0" ]]; then
            error "Delete apiservcie ${api} failed"
            rc=$((rc + 1))
            continue
        fi
        done
    fi
    return $rc
}

function cleanup_dedicate_cr() {
    for ns in ${TENANT_NAMESPACES//,/ }; do
        cleanup_webhook $ns $TENANT_NAMESPACES
        cleanup_secretshare $ns $TENANT_NAMESPACES
        cleanup_crossplane $ns
    done
}

function delete_tenant_ns() {
    title "Deleting tenant namespaces"
    for ns in ${TENANT_NAMESPACES//,/ }; do
        ${OC} delete --ignore-not-found ns "$ns" --timeout=30s
        if [ $? -ne 0 ] || [ $FORCE_DELETE -eq 1 ]; then
            warning "Failed to delete namespace $ns, force deleting remaining resources..."
            remove_all_finalizers $ns && success "Namespace $ns is deleted successfully."
        fi
        update_namespaceMapping $ns
    done

    cleanup_cs_control

    success "Common Services uninstall finished and successful." 
}

function update_namespaceMapping() {
    namespace=$1
    title "Updating common-service-maps $namespace"
    msg "-----------------------------------------------------------------------"
    local current_yaml=$("${OC}" get -n kube-public cm common-service-maps -o yaml | ${YQ} '.data.["common-service-maps.yaml"]')
    local isExist=$(echo "$current_yaml" | ${YQ} '.namespaceMapping[] | select(.map-to-common-service-namespace == "'$namespace'")')

    if [ "$isExist" ]; then
        info "The map-to-common-service-namespace: $namespace, exist in common-service-maps"
        info "Deleting this tenant in common-service-maps"
        updated_yaml=$(echo "$current_yaml" | ${YQ} 'del(.namespaceMapping[] | select(.map-to-common-service-namespace == "'$namespace'"))')
        local padded_yaml=$(echo "$updated_yaml" | awk '$0="    "$0')
        update_cs_maps "$padded_yaml"
    else
        info "Namespace: $namespace does not exist in .map-to-common-service-namespace, skipping"
    fi
}

# update_cs_maps Updates the common-service-maps with the given yaml. Note that
# the given yaml should have the right indentation/padding, minimum 2 spaces per
# line. If there are multiple lines in the yaml, ensure that each line has
# correct indentation.
function update_cs_maps() {
    local yaml=$1

    local object="$(
        cat <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: common-service-maps
  namespace: kube-public
data:
  common-service-maps.yaml: |
${yaml}
EOF
)"
    echo "$object" | ${OC} apply -f -
}

# check if we need to cleanup contorl namespace and clean it
function cleanup_cs_control() {
    local current_yaml=$("${OC}" get -n kube-public cm common-service-maps -o yaml | ${YQ} '.data.["common-service-maps.yaml"]')
    local isExist=$(echo "$current_yaml" | ${YQ} '.namespaceMapping[] | has("map-to-common-service-namespace")' )
    if [ "$isExist" ]; then
        info "map-to-common-service-namespace exist in common-service-maps, don't clean up control namespace"
    else
        title "Clean up control namespace"
        msg "-----------------------------------------------------------------------"
        get_control_namespace
        # cleanup namespaceScope in Control namespace
        cleanup_NamespaceScope $CONTROL_NS
        # cleanup webhook
        cleanup_webhook $CONTROL_NS ""
        # cleanup secretshare
        cleanup_secretshare $CONTROL_NS ""
        # cleanup crossplane    
        cleanup_crossplane
        # delete common-service-maps 
        ${OC} delete configmap common-service-maps -n kube-public
        # delete namespace
        ${OC} delete --ignore-not-found ns "$CONTROL_NS" --timeout=30s
        if [ $? -ne 0 ] || [ $FORCE_DELETE -eq 1 ]; then
            warning "Failed to delete namespace $CONTROL_NS, force deleting remaining resources..."
            remove_all_finalizers $ns && success "Namespace $CONTROL_NS is deleted successfully."
        fi

        success "Control namespace: ${CONTROL_NS} is cleanup"
    fi

}

# Util functions
function msg() {
    printf '%b\n' "$1"
}

function info() {
    msg "[INFO] ${1}"
}

function success() {
    msg "\33[32m[✔] ${1}\33[0m"
}

function warning() {
    msg "\33[33m[✗] ${1}\33[0m"
}

function error() {
    msg "\33[31m[✘] ${1}\33[0m"
    exit 1
}

function title() {
    msg "\33[34m# ${1}\33[0m"
}

function debug() {
    msg "\33[33m[DEBUG] ${1}\33[0m"
}

function save_log(){
    local LOG_DIR="$BASE_DIR/$1"
    LOG_FILE="$LOG_DIR/$2_$(date +'%Y%m%d%H%M%S').log"
    local debug=$3

    if [ $debug -eq 1 ]; then
        if [[ ! -d $LOG_DIR ]]; then
            mkdir -p "$LOG_DIR"
        fi

        # Create a named pipe
        PIPE=$(mktemp -u)
        mkfifo "$PIPE"

        # Tee the output to both the log file and the terminal
        tee "$LOG_FILE" < "$PIPE" &

        # Redirect stdout and stderr to the named pipe
        exec > "$PIPE" 2>&1

        # Remove the named pipe
        rm "$PIPE"
    fi
}

function cleanup_log() {
    # Check if the log file already exists
    if [[ -e $LOG_FILE ]]; then
        # Remove ANSI escape sequences from log file
        sed -E 's/\x1B\[[0-9;]+[A-Za-z]//g' "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
}

function check_command() {
    local command=$1

    if [[ -z "$(command -v ${command} 2> /dev/null)" ]]; then
        error "${command} command not available"
    else
        success "${command} command available"
    fi
}

function check_yq_version() {
  yq_version=$("${YQ}" --version | awk '{print $NF}' | sed 's/^v//')
  yq_minimum_version=4.18.1

  if [ "$(printf '%s\n' "$yq_minimum_version" "$yq_version" | sort -V | head -n1)" != "$yq_minimum_version" ]; then 
    error "yq version $yq_version must be at least $yq_minimum_version or higher.\nInstructions for installing/upgrading yq are available here: https://github.com/marketplace/actions/yq-portable-yaml-processor"
  fi
}

function wait_for_condition() {
    local condition=$1
    local retries=$2
    local sleep_time=$3
    local wait_message=$4
    local success_message=$5
    local error_message=$6

    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        if [[ ( ${retries} -eq 0 ) && ( -z "${result}" ) ]]; then
            error "${error_message}"
        fi

        sleep ${sleep_time}
        result=$(eval "${condition}")

        if [[ -z "${result}" ]]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}\n"
    fi
}

function fetch_sub_from_package() {
    local package=$1
    local ns=$2

    ${OC} get subscription.operators.coreos.com -n "$ns" -o jsonpath="{.items[?(@.spec.name=='$package')].metadata.name}"
}

function fetch_csv_from_sub() {
    local sub=$1
    local ns=$2

    ${OC} get csv -n "$ns" | grep "$sub" | cut -d ' ' -f1
}

# clean up webhook deployment and webhookconfiguration
function cleanup_webhook() {
    local control_ns=$1
    local nss_list=$2
    for ns in ${nss_list//,/ }
    do
        info "Deleting podpresets in namespace $ns..."
        ${OC} get podpresets.operator.ibm.com -n $ns --no-headers | awk '{print $1}' | xargs ${OC} delete -n $ns --ignore-not-found podpresets.operator.ibm.com
    done
    msg ""

    cleanup_deployment "ibm-common-service-webhook" $control_ns

    info "Deleting MutatingWebhookConfiguration..."
    ${OC} delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration --ignore-not-found
    ${OC} delete MutatingWebhookConfiguration ibm-operandrequest-webhook-configuration --ignore-not-found
    msg ""

    info "Deleting ValidatingWebhookConfiguration..."
    ${OC} delete ValidatingWebhookConfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

}

# TODO: clean up secretshare deployment and CR in service_ns
function cleanup_secretshare() {
    local control_ns=$1
    local nss_list=$2

    for ns in ${nss_list//,/ }
    do
        info "Deleting SecretShare in namespace $ns..."
        ${OC} get secretshare -n $ns --no-headers | awk '{print $1}' | xargs ${OC} delete -n $ns --ignore-not-found secretshare
    done
    msg ""

    cleanup_deployment "secretshare" "$control_ns"

}

# TODO: clean up crossplane sub and CR in operator_ns and service_ns
function cleanup_crossplane() {
    #check if crossplane operator is installed or not
    local is_exist=$($OC get subscription.operators.coreos.com -A --no-headers | (grep ibm-crossplane || echo "fail") | awk '{print $1}')
    if [[ $is_exist != "fail" ]]; then
        # delete CR
        info "cleanup crossplane CR"
        ${OC} get configuration.pkg.ibm.crossplane.io -A --no-headers | awk '{print $1}' | xargs ${OC} delete --ignore-not-found configuration.pkg.ibm.crossplane.io
        ${OC} get lock.pkg.ibm.crossplane.io -A --no-headers | awk '{print $1}' | xargs ${OC} delete --ignore-not-found lock.pkg.ibm.crossplane.io
        ${OC} get ProviderConfig -A --no-headers | awk '{print $1}' | xargs ${OC} delete --ignore-not-found ProviderConfig

        sleep 30

        # delete Sub
        info "cleanup crossplane Subscription and ClusterServiceVersion"
        local namespace=$($OC get subscription.operators.coreos.com -A --no-headers | (grep ibm-crossplane-operator-app || echo "fail") | awk '{print $1}')
        if [[ $namespace != "fail" ]]; then
            delete_operator "ibm-crossplane-provider-kubernetes-operator-app" "$namespace"
            delete_operator "ibm-crossplane-provider-ibm-cloud-operator-app" "$namespace"
            delete_operator "ibm-crossplane-operator-app" "$namespace"
        fi
    else
        info "crossplane operator not exist, skip clean crossplane"
    fi
}

function remove_all_finalizers() {
    local ns=$1

    apiGroups=$(${OC} api-resources --namespaced -o name)
    delete_operand_finalizer "${apiGroups}" "${ns}"

}

function delete_operand_finalizer() {
    local crds=$1
    local ns=$2
    for crd in ${crds}; do
        if [ "${crd}" != "packagemanifests.packages.operators.coreos.com" ] && [ "${crd}" != "events" ] && [ "${crd}" != "events.events.k8s.io" ]; then
            crs=$(${OC} get "${crd}" --no-headers --ignore-not-found -n "${ns}" 2>/dev/null | awk '{print $1}')
            for cr in ${crs}; do
                msg "Removing the finalizers for resource: ${crd}/${cr}"
                ${OC} patch ${crd} ${cr} -n ${ns} --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]' 2>/dev/null
            done
        fi
    done
}

function get_control_namespace() {
    # Define the ConfigMap name and namespace
    local config_map_name="common-service-maps"

    # Get the ConfigMap data
    config_map_data=$(${OC} get configmap "${config_map_name}" -n kube-public -o yaml --ignore-not-found | ${YQ} '.data[]')

    # Check if the ConfigMap exists
    if [[ -z "${config_map_data}" ]]; then
        warning "Not found common-serivce-maps ConfigMap in kube-public namespace. It is a single shared Common Service instance or all namespace mode upgrade"
    else
        # Get the controlNamespace value
        control_namespace=$(echo "${config_map_data}" | ${YQ} -r '.controlNamespace')

        # Check if the controlNamespace key exists
        if [[ "${control_namespace}" == "null" ]] || [[ "${control_namespace}" == "" ]]; then
            warning "No controlNamespace is found from common-serivce-maps ConfigMap in kube-public namespace. It is a single shared Common Service instance upgrade"
        else
            CONTROL_NS=$control_namespace
        fi
    fi
}

main $*
