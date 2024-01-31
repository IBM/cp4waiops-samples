#!/usr/bin/env bash
#
# © Copyright IBM Corp. 2020, 2023
# SPDX-License-Identifier: Apache2.0
#
# This script can be used to migrate from v3 to v4
# Cert Manager and Licensing after AIOps upgrade to 4.4.0
#
# This script is a modified migrate_singleton.sh from IBM Common Services GitHub at version
# https://github.com/IBM/ibm-common-service-operator/commit/567fef2e687e1c0ee56298a9b2c50b7fe9d1c0e1

# ---------- Command arguments ----------

OC=oc
YQ=yq
OPERATOR_NS="ibm-common-services"
CONTROL_NS="cs-control"
SOURCE_NS="openshift-marketplace"
ENABLE_LICENSING=1
ENABLE_LICENSE_SERVICE_REPORTER=0
LSR_NAMESPACE="ibm-lsr"
LICENSING_NS="ibm-licensing"
NEW_MAPPING=""
NEW_TENANT=0
DEBUG=0
PREVIEW_MODE=0

# ---------- Command variables ----------

# script base directory
BASE_DIR=$(cd $(dirname "$0")/$(dirname "$(readlink $0)") && pwd -P)

# counter to keep track of installation steps
STEP=0

# ---------- Main functions ----------

function main() {
    parse_arguments "$@"
    pre_req

    # Delete CP2.0 Cert-Manager CR
    ${OC} delete certmanager.operator.ibm.com default --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        warning "Failed to delete Cert Manager CR, patching its finalizer to null..."
        ${OC} patch certmanagers.operator.ibm.com default --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi

    if [ ! -z "$CONTROL_NS" ]; then
        # Delegation of CP2 Cert Manager
        deactivate_cp2_cert_manager
    fi

    delete_operator "ibm-cert-manager-operator" "$OPERATOR_NS"
    
    if [[ $ENABLE_LICENSING -eq 1 ]]; then
        # Migrate Licensing Services Data
        migrate_lic_cms
        local is_deleted=$(("${OC}" delete -n "${CONTROL_NS}" --ignore-not-found OperandBindInfo ibm-licensing-bindinfo --timeout=10s > /dev/null && echo "success" ) || echo "fail")
        if [[ $is_deleted == "fail" ]]; then
            warning "Failed to delete OperandBindInfo, patching its finalizer to null..."
            ${OC} patch -n "${CONTROL_NS}" OperandBindInfo ibm-licensing-bindinfo --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
        fi

        if [[ $ENABLE_LICENSE_SERVICE_REPORTER -eq 1 ]]; then
            migrate_license_service_reporter
        fi

        backup_ibmlicensing
        is_exists=$("${OC}" get deployments -n "${CONTROL_NS}" --ignore-not-found ibm-licensing-operator)
        if [ ! -z "$is_exists" ]; then
            "${OC}" delete --ignore-not-found ibmlicensing instance
        fi

        # Delete licensing csv/subscriptions
        delete_operator "ibm-licensing-operator" "$OPERATOR_NS"

        # restore licensing configuration so that subsequent License Service install will pick them up
        restore_ibmlicensing
    fi

    success "Migration is completed for Cloud Pak 3.0 Foundational singleton services."
}

function migrate_license_service_reporter(){
    title "LSR migration from ibm-cmmon-services to ${LSR_NAMESPACE}"

    local lsr_instances=$("$OC" get IBMLicenseServiceReporter instance -n ${OPERATOR_NS} --no-headers | wc -l)
    if [[ lsr_instances -eq 0 ]]; then
        info "No LSR for migration found in ${OPERATOR_NS} namespace"
        return 0
    fi

    lsr_pv_nr=$("${OC}" get pv -l license-service-reporter-pv=true --no-headers | wc -l )
    if [[ lsr_pv_nr -ne 1 ]]; then
        warning "Expecting exactly one PV with label license-service-reporter-pv=true. $lsr_pv_nr found. Migration skipped."
        return 0
    fi

    # Prepare LSR PV/PVC which was decoupled in isolate.sh
    # delete old LSR CR - PV will stay as during isolate.sh the policy was set to Retain
    ${OC} delete IBMLicenseServiceReporter instance -n ${OPERATOR_NS}

    # in case PVC is blocked with deletion, the finalizer needs to be removed
    lsr_pvcs=$("${OC}" get pvc license-service-reporter-pvc -n ${OPERATOR_NS}  --no-headers | wc -l)
    if [[ lsr_pvcs -gt 0 ]]; then
        info "Failed to delete pvc license-service-reporter-pvc, patching its finalizer to null..."
        ${OC} patch pvc license-service-reporter-pvc -n ${OPERATOR_NS}  --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    else
        debug1 "No pvc license-service-reporter-pvc as expected"
    fi

    if [[ lsr_pv_nr -eq 1 ]]; then
        debug1 "LSR namespace: ${LSR_NAMESPACE}" 
        create_namespace "${LSR_NAMESPACE}"

        # get storage class name
        LSR_PV_NAME=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath='{.items[0].metadata.name}')
        debug1 "PV name: $LSR_PV_NAME"
        
        # on ROKS storage class name cannot be proviced during PVC creation
        roks=$(${OC} cluster-info | grep 'containers.cloud.ibm.com')
        if [[ -z $roks ]]; then
            LSR_STORAGE_CLASS=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath='{.items[0].spec.storageClassName}')
            if [[ -z $LSR_STORAGE_CLASS ]]; then
                error "Cannnot get storage class name from PVC license-service-reporter-pv in $LSR_NAMESPACE"
            fi
        else
            debug1 "Run on ROKS, not setting storageclass name"
            LSR_STORAGE_CLASS=""
                       
            deprecated_region='{.items[0].metadata.labels.failure-domain\.beta\.kubernetes\.io\/region}'
            deprecated_zone='{.items[0].metadata.labels.failure-domain\.beta\.kubernetes\.io\/zone}'


            deprecated_region_label='failure-domain.beta.kubernetes.io/region'
            not_deprecated_region_label='topology.kubernetes.io/region'
            deprecated_zone_label='failure-domain.beta.kubernetes.io/zone'
            not_deprecated_zone_label='topology.kubernetes.io/zone'

            region=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath=$deprecated_region)
            zone=$("${OC}" get pv -l license-service-reporter-pv=true -o=jsonpath=$deprecated_zone)

            if [[ $region != "" ]]; then
                debug1 "Replacing depracated PV labels"
                "${OC}" label pv $LSR_PV_NAME $not_deprecated_region_label=$region $deprecated_region_label- $not_deprecated_zone_label=$zone $deprecated_zone_label- --overwrite 
            fi
        fi

        # create PVC
        TEMP_LSR_PVC_FILE="_TEMP_LSR_PVC_FILE.yaml"

        cat <<EOF >$TEMP_LSR_PVC_FILE
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
            name: license-service-reporter-pvc
            namespace: ${LSR_NAMESPACE}
        spec:
            accessModes:
            - ReadWriteOnce
            resources:
                requests:
                    storage: 1Gi
            storageClassName: "${LSR_STORAGE_CLASS}"
            volumeMode: Filesystem
            volumeName: ${LSR_PV_NAME}
EOF

        ${OC} create -f ${TEMP_LSR_PVC_FILE}
        # checking status of PVC - in case it cannot be boud, the claimRef needs to be set to null
        status=$("${OC}" get pvc license-service-reporter-pvc -n $LSR_NAMESPACE --no-headers | awk '{print $2}')
        while [[ "$status" != "Bound" ]]
        do
            namespace=$("${OC}" get pv ${LSR_PV_NAME} -o=jsonpath='{.spec.claimRef.namespace}')
            if [[ $namespace != $LSR_NAMESPACE ]]; then
                ${OC} patch pv ${LSR_PV_NAME} --type=merge -p '{"spec": {"claimRef":null}}'
            fi
            info "Waiting for pvc license-service-reporter-pvc to bind"
            sleep 10
            status=$("${OC}" get pvc license-service-reporter-pvc -n $LSR_NAMESPACE --no-headers | awk '{print $2}')
        done
    fi
}


function restore_ibmlicensing() {

    is_exist=$("${OC}" get cm ibmlicensing-instance-bak -n ${LICENSING_NS} --ignore-not-found)
    if [[ -z "${is_exist}" ]]; then
        warning "No IBMLicensing instance backup found, skipping restore"
        return
    fi
    # extracts the previously saved IBMLicensing CR from ConfigMap and creates the IBMLicensing CR
    "${OC}" get cm ibmlicensing-instance-bak -n ${LICENSING_NS} -o yaml --ignore-not-found | "${YQ}" .data | sed -e 's/.*ibmlicensing.yaml.*//' | 
    sed -e 's/^  //g' | "${OC}" apply -f -
    
    if [[ $? -ne 0 ]]; then
        warning "Failed to restore IBMLicensing instance"
    else
        success "IBMLicensing instance is restored"
    fi

}

function backup_ibmlicensing() {
    create_namespace "${LICENSING_NS}"

    ls_instance=$("${OC}" get IBMLicensing instance --ignore-not-found -o yaml)
    if [[ -z "${ls_instance}" ]]; then
        echo "No IBMLicensing instance found, skipping backup"
        return
    fi
 
    # If LS connected to LicSvcReporter, set a template for sender configuration with url pointing to the IBM LSR docs
    # And create an empty secret 'ibm-license-service-reporter-token' in LS_new_namespace to ensure that LS instance pod will start
    local reporterURL=$(echo "${ls_instance}" | "${YQ}" '.spec.sender.reporterURL')
    if [[ "$reporterURL" != "null" ]]; then
        info "The current sender configuration for sending data from License Service to License Servive Reporter:" 
        echo "${ls_instance}" | "${YQ}" '.spec.sender'
        info "Resetting to a sender configuration template. Please follow the link ibm.biz/lsr_sender_config for more information"
        "${OC}" create secret generic -n ${LICENSING_NS} ibm-license-service-reporter-token
        instance=`"${OC}" get IBMLicensing instance -o yaml --ignore-not-found | "${YQ}" '
            with(.; del(.metadata.creationTimestamp) |
            del(.metadata.managedFields) |
            del(.metadata.resourceVersion) |
            del(.metadata.uid) |
            del(.status) | 
            (.spec.sender.reporterURL)="https://READ_(ibm.biz/lsr_sender_config)" |
            (.spec.sender.reporterSecretToken)="ibm-license-service-reporter-token"
            )
        ' | sed -e 's/^/    /g'`
    else
        instance=`"${OC}" get IBMLicensing instance -o yaml --ignore-not-found | "${YQ}" '
            with(.; del(.metadata.creationTimestamp) |
            del(.metadata.managedFields) |
            del(.metadata.resourceVersion) |
            del(.metadata.uid) |
            del(.status)
            )
        ' | sed -e 's/^/    /g'`
    fi
    debug1 "instance: $instance"
cat << _EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ibmlicensing-instance-bak
  namespace: ${LICENSING_NS}
data:
  ibmlicensing.yaml: |
${instance}
_EOF

    if [[ $? -ne 0 ]]; then
        warning "Failed to backup IBMLicensing instance"
    else
        success "IBMLicensing instance is backed up"
    fi
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
        --control-namespace)
            shift
            CONTROL_NS=$1
            ;;
        --licensing-namespace)
            shift
            LICENSING_NS=$1
            ;;
        --enable-licensing)
            ENABLE_LICENSING=1
            ;;
        --enable-license-service-reporter)
            ENABLE_LICENSE_SERVICE_REPORTER=1
            ;;
        --lsr-namespace)
            shift
            LSR_NAMESPACE=$1
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
    echo "Usage: ${script_name} --operator-namespace <foundational-services-namespace> [OPTIONS]..."
    echo ""
    echo "Migrate Cloud Pak 2.0 Foundational singleton services to in Cloud Pak 3.0 Foundational singleton services"
    echo "The --operator-namespace defaults to ibm-common-services. If this is incorrect, the --operator-namespace must be provided."
    echo ""
    echo "Options:"
    echo "   --oc string                                    File path to oc CLI. Default uses oc in your PATH"
    echo "   --yq string                                    File path to yq CLI. Default uses yq in your PATH"
    echo "   --operator-namespace string                    Namespace to migrate Foundational services operator. Defaults to ibm-common-services."
    echo "   --enable-licensing                             Set this flag to migrate IBM Licensing operator"
    echo "   --licensing-namespace                          Namespace to migrate Licensing. Defaults to ibm-licensing."
    echo "   -v, --debug integer                            Verbosity of logs. Default is 0. Set to 1 for debug logs."
    echo "   -h, --help                                     Print usage information"
    echo ""
}

function pre_req() {
    if [ "$CONTROL_NS" == "" ]; then
        CONTROL_NS=$OPERATOR_NS
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
}

# delegate_cp2_cert_manager.sh
function deactivate_cp2_cert_manager() {
    title "De-activating IBM Cloud Pak 2.0 Cert Manager in ${CONTROL_NS}...\n"

    info "Configuring Common Services Cert Manager.."
    result=$(${OC} get configmap ibm-cpp-config -n ${CONTROL_NS} -o yaml --ignore-not-found)
    if [[ -z "${result}" ]]; then
        cat <<EOF > ibm-cpp-config.yaml
kind: ConfigMap
apiVersion: v1
metadata:
    name: ibm-cpp-config
    namespace: ${CONTROL_NS}
data:
    deployCSCertManagerOperands: "false"
EOF
    else
        ${OC} get configmap ibm-cpp-config -n ${CONTROL_NS} -o yaml | ${YQ} eval 'select(.kind == "ConfigMap") | .data += {"deployCSCertManagerOperands": "'"false"'"}' > ibm-cpp-config.yaml
    fi
    
    
    ${OC} apply -f ibm-cpp-config.yaml
    if [ $? -ne 0 ]; then
        rm ibm-cpp-config.yaml
        error "Failed to patch ibm-cpp-config ConfigMap in ${CONTROL_NS}"
    fi
    rm ibm-cpp-config.yaml
    msg ""

    info "Deleting existing Cert Manager CR..."
    ${OC} delete certmanager.operator.ibm.com default --ignore-not-found --timeout=10s
    if [ $? -ne 0 ]; then
        warning "Failed to delete Cert Manager CR, patching its finalizer to null..."
        ${OC} patch certmanagers.operator.ibm.com default --type="json" -p '[{"op": "remove", "path":"/metadata/finalizers"}]'
    fi
    msg ""

    is_exist=$(${OC} get pod -l name=ibm-cert-manager-operator -n ${CONTROL_NS} --ignore-not-found | grep "ibm-cert-manager-operator" || echo "failed")
    if  [[ $is_exist != "failed" ]]; then
        info "Restarting IBM Cloud Pak 2.0 Cert Manager to provide cert-rotation only..."
            ${OC} delete pod -l name=ibm-cert-manager-operator -n ${CONTROL_NS} --ignore-not-found
        msg ""
        wait_for_pod ${CONTROL_NS} "ibm-cert-manager-operator"
    else
        warning "IBM Cloud Pak 2.0 Cert Manager does not exist in namespace ${CONTROL_NS}, skip restarting cert manager pod..."
    fi
    wait_for_no_pod ${CONTROL_NS} "cert-manager-cainjector"
    wait_for_no_pod ${CONTROL_NS} "cert-manager-controller"
    wait_for_no_pod ${CONTROL_NS} "cert-manager-webhook"

}

# migrate_cp2_licensing.sh
function migrate_lic_cms() {
    
    title "Migrating IBM License Service data from ${OPERATOR_NS} into ${LICENSING_NS} namespace"

    POSSIBLE_CONFIGMAPS=("ibm-licensing-config"
"ibm-licensing-annotations"
"ibm-licensing-products"
"ibm-licensing-products-vpc-hour"
"ibm-licensing-cloudpaks"
"ibm-licensing-products-groups"
"ibm-licensing-cloudpaks-groups"
"ibm-licensing-cloudpaks-metrics"
"ibm-licensing-products-metrics"
"ibm-licensing-products-metrics-groups"
"ibm-licensing-cloudpaks-metrics-groups"
"ibm-licensing-services"
)

    for configmap in ${POSSIBLE_CONFIGMAPS[@]}
    do
        ${OC} get configmap "${configmap}" -n "${OPERATOR_NS}" > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
            info "Copying Licensing Services ConfigMap $configmap from $OPERATOR_NS to $LICENSING_NS"
            ${OC} get configmap "${configmap}" -n "${OPERATOR_NS}" -o yaml | ${YQ} -e '.metadata.namespace = "'${LICENSING_NS}'"' > ${configmap}.yaml
            ${YQ} eval 'select(.kind == "ConfigMap") | del(.metadata.resourceVersion) | del(.metadata.uid)' ${configmap}.yaml | ${OC} apply -f -

            if [[ $? -eq 0 ]]; then
                info "Licensing Services ConfigMap $configmap is copied from $OPERATOR_NS to $LICENSING_NS"
                # delete the original
                ${OC} delete cm -n $OPERATOR_NS $configmap --ignore-not-found
            else
                error "Failed to move Licensing Services ConfigMap $configmap to $LICENSING_NS"
            fi

            rm ${configmap}.yaml
            msg ""
        fi
    done
    success "Licensing Service ConfigMaps are migrated from $OPERATOR_NS to $LICENSING_NS"
}

# Utility functions

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

function delete_operator() {
    subs=$1
    ns=$2
    for sub in ${subs}; do
        title "Deleting ${sub} in namesapce ${ns}..."
        csv=$(${OC} get subscription.operators.coreos.com ${sub} -n ${ns} -o=jsonpath='{.status.installedCSV}' --ignore-not-found)
        in_step=1
        msg "[${in_step}] Removing the subscription of ${sub} in namesapce ${ns} ..."
        ${OC} delete sub ${sub} -n ${ns} --ignore-not-found
        in_step=$((in_step + 1))
        msg "[${in_step}] Removing the csv of ${sub} in namesapce ${ns} ..."
        [[ "X${csv}" != "X" ]] && ${OC} delete csv ${csv}  -n ${ns} --ignore-not-found
        msg ""

        success "Remove $sub successfully."
        msg ""
    done
}

function create_namespace() {
    local namespace=$1
    title "Checking whether Namespace $namespace exist..."
    if [[ -z "$(${OC} get namespace ${namespace} --ignore-not-found)" ]]; then
        info "Creating namespace ${namespace}"
        ${OC} create namespace ${namespace}
        if [[ $? -ne 0 ]]; then
            error "Error creating namespace ${namespace}"
        fi
        if [[ $PREVIEW_MODE -eq 0 ]]; then
            wait_for_project ${namespace}
        fi
    else
        success "Namespace ${namespace} already exists. Skip creating\n"
    fi
}

function wait_for_project() {
    local name=$1
    local condition="${OC} get project ${name} --no-headers --ignore-not-found"
    local retries=12
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for project ${name} to be created"
    local success_message="Project ${name} is created"
    local error_message="Timeout after ${total_time_mins} minutes waiting for project ${name} to be created"

    wait_for_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
}

function wait_for_no_pod() {
    local namespace=$1
    local name=$2
    local condition="${OC} -n ${namespace} get po --no-headers --ignore-not-found | grep ^${name}"
    local retries=30
    local sleep_time=10
    local total_time_mins=$(( sleep_time * retries / 60))
    local wait_message="Waiting for pod ${name} in namespace ${namespace} to be deleting"
    local success_message="Pod ${name} in namespace ${namespace} is deleted"
    local error_message="Timeout after ${total_time_mins} minutes waiting for pod ${name} in namespace ${namespace} to be deleted"

    wait_for_not_condition "${condition}" ${retries} ${sleep_time} "${wait_message}" "${success_message}" "${error_message}"
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

function wait_for_not_condition() {
    local condition=$1
    local retries=$2
    local sleep_time=$3
    local wait_message=$4
    local success_message=$5
    local error_message=$6

    info "${wait_message}"
    while true; do
        result=$(eval "${condition}")

        if [[ ( ${retries} -eq 0 ) && ( ! -z "${result}" ) ]]; then
            error "${error_message}"
        fi

        sleep ${sleep_time}
        result=$(eval "${condition}")

        if [[ ! -z "${result}" ]]; then
            info "RETRYING: ${wait_message} (${retries} left)"
            retries=$(( retries - 1 ))
        else
            break
        fi
    done

    if [[ ! -z "${success_message}" ]]; then
        success "${success_message}"
    fi
}

function debug1() {
    if [ $DEBUG -eq 1 ]; then
       debug "${1}"
    fi
}

main "$@"
