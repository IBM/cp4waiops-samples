#!/bin/bash
# © Copyright IBM Corp. 2020, 2025

set -eo pipefail

res_file=$(mktemp)

## Resource size for 4.9
# These defaults are given in section 'IBM Cloud Pak for AIOps only Hardware requirement totals' under
# Minimum resource values for Production sized 4.9.x (base install)
NODE_COUNT_LARGE_4_5=6
VCPU_LARGE_4_5=148
MEMORY_LARGE_4_5=358


# Minumim resource values for production extended
VCPU_LARGE_LAD=174
MEM_LARGE_LAD=416


# Utilities
notop=""
adm="adm"
unitNotSupported="false"
SIZE=""

# Tracing prefixes
INFO="[INFO]"
WARNING="[WARNING]"
ERROR="[ERROR]"

# For Summary method
OCP_VER_RES=""
STORAGE_PROVIDER_RES=""
LARGE_PROFILE_RES=""
CERTMANAGER_PRESENT=""
LICENSING_PRESENT=""
MZ_RES=""
RQ_RES=""

warn_color="\x1b[33m"
fail_color="\x1b[31m"
pass_color="\e[32m"
color_end="\x1b[0m"

fail_msg=`printf "$fail_color FAIL $color_end"`
pass_msg=`printf "$pass_color PASS $color_end\n"`
warning_msg=`printf "$warn_color WARNING $color_end"`
skip_msg=`printf "$warn_color SKIP $color_end"`

# array to hold all storage check results
storageCheckRes=()

log () {
    local log_tracing_prefix=$1
    local log_message=$2
    local log_color=$3


    if [[ $log_color != "" ]]; then
        printf "$log_color$log_tracing_prefix $log_message$color_end\n" | tee -a $res_file
    else
        echo "$log_tracing_prefix $log_message" | tee -a $res_file
    fi
}

display_help() {
    echo "**************************************** Usage ********************************************"
    echo
    echo " This script ensures that you have met the technical prerequisites for IBM Cloud Pak for AIOps version 4.9."
    echo
    echo " Before you run this script, you will need: "
    echo " 1. OpenShift (oc) command line interface (CLI) or kubectl if you are deploying a VM Based install"
    echo " 2. Must be logged in to your cluster with oc/kubectl login"
    echo " 3. Must be in the project (namespace) you have installed or will install the product in"
    echo
    echo " Usage:"
    echo " ./prereq.sh -h"
    echo "  -h Prints out the help message"
    echo " ./prereq.sh -n"
    echo "  -n Namespace where CP4AIOPS will be installed"
    echo " ./prereq.sh -o"
    echo "  -o Skips storageclass checks when using alternate storage providers"
    echo " ./prereq.sh -m"
    echo "  -m Enabling this check will allow the prereq script validate if the cluster is properly configured for multizone."
    echo " ./prereq.sh --ignore-allocated"
    echo "  --ignore-allocated Will ignore allocated resources available for new installs and focus on capacity instead for nodes that are x86_64 (amd64) architecture and lack a taint called NoSchedule."
    echo " ./prereq.sh --cli <cli>"
    echo "  --cli You can pass either \"kubectl\" or \"oc\" to force the script to use the given CLI."
    echo " ./prereq.sh --skip-operator-checks"
    echo "  --skip-operator-checks This command skips checking for License Operator and Cert Manager." 
    echo "*******************************************************************************************"
}

# Add options as needed
while getopts 'homcn:-:' opt; do
    case "$opt" in
        h)
            display_help
            exit 0
            ;;
        o)
            SKIP_STORAGE_CHECK="true"
            ;;
        m)
            SHOW_MULTIZONE="true"
            ;;
        n)
            NAMESPACE="$OPTARG"
            ;;
        -)
            case "${OPTARG}" in 
                ignore-allocated)
                    echo "Ignoring Allocated..."
                    IGNORE_ALLOCATED="true"
                    ;;
                cli)
                    val="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                    if [[ "$val" == "kubectl" || "$val" == "oc" ]]; then
                        CLI=$val
                    else
                        echo "Invalid value for --CLI. It must be \"oc\" or \"kubectl\""
                        exit 1
                    fi
                    ;;
                skip-operator-checks)
                    SKIP_OPERATOR_CHECKS="true"
                    ;;
                *)
                    echo "Invalid option: --${OPTARG}" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Invalid option: -$opt" >&2
            exit 1
            ;;
    esac
done
shift "$(($OPTIND -1))"

# Check if user explicitly set CLI, if not run normal logic
if [[ "$CLI" == "" ]]; then
    # Check if oc-cli is installed
    if [ -x "$(command -v oc)" ]; then
        CLI="oc"
    # Check if kubectl is installed
    elif [ -x "$(command -v kubectl)" ]; then
        CLI="kubectl"
    # If neither oc nor kubectl is found, log an error and exit the script
    else
        log $ERROR "Neither oc nor kubectl CLI is installed. Please install either oc or kubectl CLI and try running the script again." ""
        exit 1
    fi
fi

if [[ -z "$NAMESPACE" ]]; then
    log $ERROR "The -n option is required to specify the namespace." ""
    exit 1
fi

# Check if nodes can be found
none=$(${CLI} get node)
if [[  "$?" -ne "0" ]]; then
    log $ERROR Cannot get nodes with existing RBAC Permissions. $fail_color ""
    exit $LINENO
fi

echo
log $INFO "Starting IBM Cloud Pak for AIOps prerequisite checker v4.9..." ""
echo

function checkPlatformVersion {
    echo
    startEndSection "Platform Version Check"
    log $INFO "Checking Platform Type...." ""

    # Check if openshift by checking for clusterversions crd
    ${CLI} get crd clusterversions.config.openshift.io > /dev/null 2>&1
    isOpenshift=$?
    if [[ "${isOpenshift}" == "0" ]]; then
        log $INFO "You are using Openshift Container Platform" ""
        OCP_VER=$(${CLI} get clusterversion version -o=jsonpath='{.status.desired.version}')
        OCP_MINOR_VER=`echo $OCP_VER | awk '{split($0,a,"."); print a[3]}'`
        if [[ $OCP_VER == *"4.16"* ]]; then
            if [[ $OCP_MINOR_VER -ge 4 ]]; then
                log $INFO "OCP version $OCP_VER is compatible but only nodes with x86_64 (amd64) architectures are supported at this time." $pass_color
                OCP_VER_RES=$pass_msg
                startEndSection "Platform Version Check"
                return 0
            else
                log $ERROR "OCP Version is incompatible. Required Versions: v4.14, v4.15, v4.16.4+, v4.17, v4.18." $fail_color
                log $ERROR "Your Version: v$OCP_VER" ""
                echo
                OCP_VER_RES=$fail_msg
                startEndSection "Platform Version Check"
                return 1
            fi
        elif [[ $OCP_VER == *"4.14"* || $OCP_VER == *"4.15"* || $OCP_VER == *"4.17"* || $OCP_VER == *"4.18"* ]]; then
            log $INFO "OCP version $OCP_VER is compatible but only nodes with x86_64 (amd64) architectures are supported at this time." $pass_color
            OCP_VER_RES=$pass_msg
            startEndSection "Platform Version Check"
            return 0
        else
            log $ERROR "OCP Version is incompatible. Required Versions: v4.14, v4.15, v4.16.4+, v4.17, v4.18." $fail_color
            log $ERROR "Your Version: v$OCP_VER" ""
            echo
            OCP_VER_RES=$fail_msg
            startEndSection "Platform Version Check"
            return 1
        fi
    else
        log $INFO "Non-OCP Cluster Found. Checking for Kubernetes Server version." ""
        local version=$(kubectl version 2>/dev/null | awk '/Server Version:/ {split($3,a,"."); print a[1]"."a[2]}')
        local version_number=$(echo $version | tr -d 'v')
        local minor_version="${version_number#*.}"
        local maj_version="${version_number%%.*}"


        if [[ "$maj_version" -eq "1" && "$minor_version" -ge "27" ]]; then
            log $INFO "Kubernetes server version met!" ""
            OCP_VER_RES=$pass_msg
            startEndSection "Platform Version Check"
            return 0
        else
            log $ERROR "Kubernetes server version is incompatible. Required version: v1.27 or greater" $fail_color
            echo
            OCP_VER_RES=$fail_msg
            startEndSection "Platform Version Check"
            return 1
        fi
    fi

}

function checkAllowVolumeExpansion() {
    storageclass=$1
    
    volumeExpansionEnabled=$(${CLI} get storageclass $storageclass -o=jsonpath='{.allowVolumeExpansion}')
    if [[ "${volumeExpansionEnabled}" != "true" ]]; then
        return 1
    fi

    return 0
}

function checkIBMSFHCI {
    printf "\nChecking if IBM Storage Fusion HCI System is configured properly...\n" | tee -a $res_file

    IBM_SF_HCI_VE=$(checkAllowVolumeExpansion ibm-storage-fusion-cp-sc)
    if [[ "$?" == "1" ]]; then
        log $ERROR "StorageClass ibm-storage-fusion-cp-sc does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        storageCheckRes+=("fail")
        return 1       
    fi

    storageCheckRes+=("pass")
    printf "IBM Storage Fusion HCI System looks fine." | tee -a $res_file
    return 0
}

function checkIBMStorageFusion {
    MEETS_OCP_VERSION="false"

    printf "\nChecking if IBM Storage Fusion is configured properly...\n" | tee -a $res_file

    OCP_VER=$(${CLI} get clusterversion version -o=jsonpath='{.status.desired.version}')
    if [[ "$OCP_VER" == *"4.14"* || "$OCP_VER" == *"4.15"* || "$OCP_VER" == *"4.16"* || "$OCP_VER" == *"4.17"*  ]]; then
        # If it meets the ocp version requirement... check if ibm-spectrum-scale-sc storageclass has volume expansion enabled
        IBM_SPEC_VE=$(checkAllowVolumeExpansion ibm-spectrum-scale-sc)
        if [[ "$?" == "1" ]]; then
            log $ERROR "StorageClass ibm-spectrum-scale-sc does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
            storageCheckRes+=("fail")
            return 1
        fi
        
        storageCheckRes+=("pass")
        printf "IBM Storage Fusion looks fine." | tee -a $res_file
        return 0
    else
        # OCP 4.12 was not found... fail this check
        log $ERROR "If you intend to use Storage Fusion with AIOPS 4.9, you must have OCP 4.14, 4.15, or 4.16" $fail_color
        log $INFO "See Readme for more info about this." ""
        storageCheckRes+=("fail")
        return 1
    fi
}

function checkODF {
    ODF_PODS=$1
    printf "\nChecking Openshift Data Foundation Configuration...\n" | tee -a $res_file
    printf "Verifying if Red Hat Openshift Data Foundation pods are in \"Running\" or \"Completed\" status\n" | tee -a $res_file

    for p in "${ODF_PODS[@]}"; do
        podStatus=$(${CLI} get pod $p -n openshift-storage -o jsonpath='{.status.phase}')
        if [[ "$podStatus" == "Running" || "$podStatus" == "Succeeded" ]]; then
            continue
        else
            log $ERROR "Pod in openshift-storage project namespace found not \"Running\" or \"Completed\": $p" $fail_color
            storageCheckRes+=("fail")
            return 1
        fi
    done

    log $INFO "Pods in openshift-storage project are \"Running\" or \"Completed\"" ""

    ODF_STORAGECLASSES=("ocs-storagecluster-ceph-rbd" "ocs-storagecluster-cephfs")
    for s in "${ODF_STORAGECLASSES[@]}"; do
        ${CLI} get storageclass $s > /dev/null 2>&1
        if [[ "$?" == "0" ]]; then
            log $INFO "$s exists." ""
        else
            log $WARNING "$s does not exist." $warn_color
            storageCheckRes+=("warn")
            return 0
        fi
    done

    # Check if each ODF StorageClass has allowVolumeExpansion enabled. If not set the ODF_VE_FLAG to true
    ODF_VE_FLAG="false"
    for s in "${ODF_STORAGECLASSES[@]}"; do
        VE_CHECK=$(checkAllowVolumeExpansion $s)
        if [[ "$?" == "1" ]]; then
            log $ERROR "StorageClass $s does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
            ODF_VE_FLAG="true"
        fi
    done

    # If the ODF_VE_FLAG is true, then that means a sc has been found that has allowvolumeexpansion disabled or missing. In that case, we'll go ahead and
    # output a failure for this check
    if [[ "$ODF_VE_FLAG" == "true" ]]; then
        storageCheckRes+=("fail")
        return 1
    fi

    storageCheckRes+=("pass")
    return 0
}

# If CSI-enabled StorageClass is not found,
#   fallback to deprecated StorageClasses
function checkNonCSIPortworx {
    printf "Checking for StorageClass \"portworx-fs\"...\n" | tee -a $res_file
    ${CLI} get storageclass portworx-fs > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
        log $INFO "StorageClass \"portworx-fs\" exists." ""
    else
        log $ERROR "No valid Portworx StorageClass found. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." 
        return 1
    fi

    printf "Checking for StorageClass \"portworx-aiops\"...\n" | tee -a $res_file
    ${CLI} get storageclass portworx-aiops > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
        log $INFO "StorageClass \"portworx-aiops\" exists." ""
    else
        log $ERROR "No valid Portworx StorageClass found. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        return 1
    fi
    
    checkAllowVolumeExpansion portworx-aiops
    if [[ "$?" == "1" ]]; then
        echo
        log $ERROR "StorageClass portworx-aiops does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See the \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        return 1
    fi

    checkAllowVolumeExpansion portworx-fs
    if [[ "$?" == "1" ]]; then
        echo
        log $ERROR "StorageClass portworx-fs does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See the \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        return 1
    fi

    # All checks passed
    return 0
}


function checkPortworx {
    printf "\nChecking Portworx Configuration...\n" | tee -a $res_file

    printf "Checking for storage class \"px-csi-aiops\"...\n" | tee -a $res_file
    ${CLI} get storageclass px-csi-aiops > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
        log $INFO "StorageClass \"px-csi-aiops\" exists." ""

        checkAllowVolumeExpansion px-csi-aiops
        if [[ "$?" == "1" ]]; then
            echo
            log $ERROR "StorageClass px-csi-aiops does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See the \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
            storageCheckRes+=("fail")
            return 1
        fi
    else
        printf "Checking for storage class \"px-csi-aiops-mz\"...\n" | tee -a $res_file
        ${CLI} get storageclass px-csi-aiops-mz > /dev/null 2>&1

        if [[ "$?" == "0" ]]; then
            log $INFO "StorageClass \"px-csi-aiops-mz\" exists." ""

            checkAllowVolumeExpansion px-csi-aiops-mz
            if [[ "$?" == "1" ]]; then
                echo
                log $ERROR "StorageClass px-csi-aiops-mz does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See the \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
                storageCheckRes+=("fail")
                return 1
            fi
        else
            log $WARNING "StorageClass \"px-csi-aiops\" and \"px-csi-aiops-mz\" do not exist." $warn_color

            # Check deprecated StorageClasses as fallback
            checkNonCSIPortworx
            if [[ "$?" == "1" ]]; then
                # No valid Portworx StorageClasses found
                storageCheckRes+=("fail")
                return 1
            fi

            # Deprecated storage class found
            log $WARNING "CSI-enabled Portworx StorageClass not found. Backup and restore using CSI snapshots will not be supported." $warn_color
            storageCheckRes+=("warn")
        fi
    fi
    
    return 0
}

function checkIBMCFileGoldGidStorage {
    printf "Checking if IBM Cloud Storage is configured properly...\n" | tee -a $res_file

    file=$(${CLI} get storageclass ibmc-file-gold-gid --ignore-not-found=true)
    block=$(${CLI} get storageclass ibmc-block-gold --ignore-not-found=true)

    if [[ "$file" == "" || "$block" == "" ]]; then
        log $ERROR "Both ibmc-block-gold and ibmc-file-gold-gid need to exist to use IBM Cloud Storage. See \"Storage\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        storageCheckRes+=("fail")
        return 1 
    fi

    VE_BLOCK=$(checkAllowVolumeExpansion ibmc-block-gold)
    if [[ "$?" == "1" ]]; then
        log $ERROR "StorageClass ibmc-block-gold does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        storageCheckRes+=("fail")
        return 1
    fi

    VE_FILE=$(checkAllowVolumeExpansion ibmc-file-gold-gid)
    if [[ "$?" == "1" ]]; then
        log $ERROR "StorageClass ibmc-file-gold-gid does not have allowedVolumeExpansion enabled. This is required for all Production sized installs and strongly recommended for starter sized installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_491 for details." $fail_color
        storageCheckRes+=("fail")
        return 1
    fi

    storageCheckRes+=("pass")
}

function checkStorage {
    # Initialize an empty array. If storage provider is found, append the name as an element...
    storageFound=()

    if [[ $SKIP_STORAGE_CHECK == "true" ]]; then
        echo
        startEndSection "Storage Provider"
        log $INFO "Skipping storage provider check" ""
        startEndSection "Storage Provider"
        STORAGE_PROVIDER_RES=$skip_msg
        return 0
    fi

    echo
    startEndSection "Storage Provider"
    log $INFO "Checking storage providers" ""

    # Check for Storage Fusion
    IBM_SPEC_SCALE=$(${CLI} get storageclass ibm-spectrum-scale-sc --ignore-not-found=true)
    if [[ "$IBM_SPEC_SCALE" != "" ]]; then
        echo
        log $INFO "A storage class related to IBM Storage Fusion was found." ""
        storageFound+=("ibm-spec")
    else
        log $INFO "No IBM Storage Fusion Found... Skipping configuration check." ""
    fi

    IBM_SF_HCI=$(${CLI} get storageclass ibm-storage-fusion-cp-sc --ignore-not-found=true)
    if [[ "$IBM_SF_HCI" != "" ]]; then
        echo
        log $INFO "A storage class related to IBM Storage Fusion HCI System was found." ""
        storageFound+=("ibm-spec-fusion-hci")
    else
        log $INFO "No IBM Storage Fusion HCI System... Skipping configuration check." ""
    fi

    # Check for any hints portworx is deployed. In this scenario, we look for any storage clusters that are deployed in all namespaces. Then
    # we check if the keyword "Running"
    STORAGE_CLUSTER=$(${CLI} get storagecluster.core.libopenstorage.org -A --ignore-not-found=true --no-headers=true 2>>/dev/null)
    if [[ "$STORAGE_CLUSTER" == *"Running"* || "$STORAGE_CLUSTER" == *"Online"* ]]; then
        log $INFO "Portworx Found. StorageCluster instance in \"Running\" or \"Online\" status found." ""
        storageFound+=("portworx")
    else
        echo
        log $INFO "No Portworx StorageClusters found with \"Running\" or \"Online\" status. Skipping configuration check for Portworx." ""
    fi

    # Check for ODF...
    ODF_PODS=($(${CLI} get pods -n openshift-storage --no-headers=true | awk '{print $1}'))
    if [[ "$ODF_PODS" == "" ]]; then
        echo
        log $INFO "Openshift Data Foundation not running. Skipping configuration check for ODF." ""
    else
        log $INFO "Openshift Data Foundation found." ""
        storageFound+=("odf")
    fi

    # Check for IBM Cloud Storage...
    IBMC_FILE_GOLD_GID=$(${CLI} get storageclass ibmc-file-gold-gid --ignore-not-found=true)
    IBMC_BLOCK_GOLD_GID=$(${CLI} get storageclass ibmc-block-gold --ignore-not-found=true)
    if [[ "$IBMC_FILE_GOLD_GID" != "" || "$IBMC_BLOCK_GOLD_GID" != ""  ]]; then
        echo
        log $INFO "IBM Cloud Storage found." ""
        storageFound+=("ibmc")
    else
        log $INFO "No IBM Cloud Storage found... Skipping configuration check for IBM Cloud Storage Check." ""
    fi

    # If no storageProviders were found, print an error...
    if [ ${#storageFound[@]} -eq 0 ]; then
        STORAGE_PROVIDER_RES=$fail_msg
        log $ERROR "At least one of the four Storage Providers are required" $fail_color
        log $ERROR "The supported Storage Providers are Portworx, Openshift Data Foundation, IBM Cloud Storage for ROKS, or IBM Spectrum Fusion/IBM Spectrum Scale Container Native. See https://ibm.biz/storage_consideration_491 for details." $fail_color
        STORAGE_PROVIDER_RES=$fail_msg
        startEndSection "Storage Provider"
        return 1
    fi

    # Check the storageFound Array if ibm cloud storage is there, if run the function to check for that storageclass
    if [[ " ${storageFound[*]} " =~ "ibmc" ]]; then
        checkIBMCFileGoldGidStorage
    fi

    # Check the storageFound Array if openshift data foundation was found. If so, run the function to check for the expected storgeclasses
    if [[ " ${storageFound[*]} " =~ "odf" ]]; then
        checkODF $ODF_PODS
    fi

    # Check the storageFound Array if portworx was found. If so, run the function to check for the expected storgeclasses
    if [[ " ${storageFound[*]} " =~ "portworx" ]]; then
        checkPortworx
    fi

    if [[ " ${storageFound[*]} " =~ "ibm-spec" ]]; then
        checkIBMStorageFusion
    fi

    if [[ " ${storageFound[*]} " =~ "ibm-spec-fusion-hci" ]]; then
        checkIBMSFHCI
    fi

    # Check if there are any failing configurations, if so we can automatically send a failure result for this check
    if [[ "${storageCheckRes[*]}" =~ "fail" ]]; then
        STORAGE_PROVIDER_RES=$fail_msg
        log $INFO "One or more errors found when checking for Storage Providers." ""
        startEndSection "Storage Provider"
        return 1
    fi

    # If we did not find any strings with "fail", then we can assume we assume we only have warnings and/or passes. First, check if
    # there are any warnings. If found we can warn the user there was one warning message that was found. Otherwise, show "Pass" for overall 
    # storage check.
    if [[ "${storageCheckRes[*]}" =~ "warn"  ]]; then
        STORAGE_PROVIDER_RES=$warning_msg
        log $INFO "One of more warnings found when checking for Storage Providers." ""
    else
        STORAGE_PROVIDER_RES=$pass_msg
        log $INFO "No warnings or failures found when checking for Storage Providers." ""
    fi

    startEndSection "Storage Provider"
    return 0 
}

get_worker_node_list() {
    if [ -z "${all_node_list}" ] ; then
        # Try to get nodes with the label type=aiops
        all_node_list=$(${CLI} get nodes -l type=aiops 2>/dev/null | grep -v NAME | awk '{ print $1 }' | sort -V | tr "\n" ' ' | tr -s ' ')
        # If the result is empty, fall back to getting all nodes
        if [ -z "${all_node_list}" ]; then
            all_node_list=$(${CLI} get nodes 2>/dev/null | grep -v NAME | awk '{ print $1 }' | sort -V | tr "\n" ' ' | tr -s ' ')
        fi
    fi    

    if [[ -z ${notop} && "${CLI}" == "oc" ]] ; then
        top=`${CLI} ${adm} top nodes`
    else
        top=`${CLI} top nodes`
    fi

    worker_node_count=0
    for node in ${all_node_list}; do
        arch=$(${CLI} get node $node -o=jsonpath='{.status.nodeInfo.architecture}')
        # Check if the node has a NoSchedule taint
        taints=$(${CLI} get node "$node" -o=jsonpath='{.spec.taints[?(@.effect=="NoSchedule")].effect}' 2>/dev/null)
        
        if [[ "$taints" != *"NoSchedule"* && "$arch" == "amd64"  ]]; then
            worker_node_count=$((worker_node_count + 1))
        else
            continue
        fi
    done
}

convert_memory_in_MB() {

    local node_mem_raw=$1
    local node_mem_without_unit=$2

    #1 Kibibyte is equal to (2^10 / 10^6) megabytes.
    #https://www.gbmb.org/kib-to-mb
    KiToMB=$(awk "BEGIN{print 2 ^ 10 / 10 ^ 6}")
    
    #1 Mebibyte is equal to (2^20 / 10^6) megabytes.
    #https://www.gbmb.org/mib-to-mb
    MiToMB=$(awk "BEGIN{print 2 ^ 20 / 10 ^ 6}")
    
    #1 Gibibyte is equal to (2^30 / 10^6) megabytes.
    #https://www.gbmb.org/gib-to-mb
    GiToMB=$(awk "BEGIN{print 2 ^ 30 / 10 ^ 6}")

    # One Tebibyte is equal to (2^40 / 10^6) megabytes.
    # https://www.gbmb.org/tib-to-mb
    TiToMB=$(awk "BEGIN{print 2 ^ 40 / 10 ^ 6}")

    # One Pebibyte is equal to (1024 ^ 5 / 1000 ^ 2) megabytes
    # https://www.dataunitconverter.com/pebibyte-to-megabyte/1#how_to_convert
    PiToMB=$(awk "BEGIN{print 1024 ^ 5 / 1000 ^ 2}")

    # One Ei is equal to (1024 ^ 6 / 1000 ^ 2) megabytes
    # https://www.dataunitconverter.com/exbibyte-to-megabyte/1
    EiToMB=$(awk "BEGIN{print 1024 ^ 6 / 1000 ^ 2}")


    #Requested memory unit can be Mi(Mebibyte) or Ki(Kibibyte), or Gi(Gibibytes) which is not the same everytime.
    #Hence we need to convert the given requested memory in MB for calculations.
    # To learn more about the different memory units, see https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/
    mem_MB=0
    if [[ "${node_mem_raw}" =~ "Ki" ]] ; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $KiToMB}")
    elif [[ "${node_mem_raw}" =~ "Mi" ]] ; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $MiToMB}")
    elif [[ "${node_mem_raw}" =~ "Gi" ]] ; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $GiToMB}")
    elif [[ "${node_mem_raw}" =~ "m" ]] ; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit / 10 ^ 9 }")
    elif [[ "${node_mem_raw}" =~ ^[0-9]+$ ]] ; then
        # Convert Bytes to MB
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit / 10 ^ 6 }")
    elif [[ "${node_mem_raw}" =~ "Ti" ]]; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $TiToMB}")
    elif [[ "${node_mem_raw}" =~ "Pi" ]]; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $PiToMB}")
    elif [[ "${node_mem_raw}" =~ "Ei" ]]; then
        mem_MB=$(awk "BEGIN{print $node_mem_without_unit * $EiToMB}")
    else
        unitNotSupported="true"
    fi
}

covert_cpu_unit() {

    local cpu_before_conversion=$1
    
    converted_cpu=0
    if [[ "${cpu_before_conversion}" =~ "m" ]] ; then
        converted_cpu=`echo ${cpu_before_conversion} | sed 's/[^0-9]*//g'`
    else
        converted_cpu=$((${cpu_before_conversion}*1000))
    fi
    
}

calculate_memory_unrequested() {
    
    #https://www.gbmb.org/kib-to-mb
    #1 Kibibyte is equal to (2^10 / 10^6) megabytes.
    KiToMB=$(awk "BEGIN{print 2 ^ 10 / 10 ^ 6}")
    
    #Allocatable raw memory of a node with unit value. eg 30998112Ki
    node_mem_raw_Ki=`echo ${node_resources} | awk '{ print $4 }'`
    node_mem_allocatable_Ki=`echo ${node_mem_raw_Ki} | sed 's/[^0-9]*//g'`

    #Allocatable memory converted in MB
    convert_memory_in_MB $node_mem_raw_Ki $node_mem_allocatable_Ki
    node_mem=$mem_MB
    
    #Requested memory for current node eg: 26958Mi or 30998112Ki
    node_mem_request_raw=`echo "${node_describe}" | grep 'memory ' -a | tail -1 | awk '{ print $2 }'`
    node_mem_request_without_unit=`echo ${node_mem_request_raw} | sed 's/[^0-9]*//g'`

    #Requested memory converted to MB
    convert_memory_in_MB $node_mem_request_raw $node_mem_request_without_unit
    node_mem_request_MB=$mem_MB

    if [[ "$IGNORE_ALLOCATED" == "true" ]]; then
        total_memory=$(awk "BEGIN{print $total_memory + $node_mem}")
        return
    fi
    
    #Available memory for new install in MB
    node_memory_unrequested_MB=$(awk "BEGIN{print $node_mem - $node_mem_request_MB}")

    #Total memory availale for new install
    total_memory=$(awk "BEGIN{print $total_memory + $node_memory_unrequested_MB}")

}

calculate_cpu_unrequested() {

    #Allocatable raw cpu from node resource
    node_cpu_raw=`echo ${node_resources} | awk '{ print $2 }'`
    
    #Requested cpu resource from node resource
    node_cpu_request=`echo "${node_describe}" | grep 'cpu ' -a | tail -1 | awk '{ print $2 }' `

    covert_cpu_unit $node_cpu_raw
    node_cpu_allocatable=$converted_cpu

    covert_cpu_unit $node_cpu_request
    node_cpu_request=$converted_cpu

    if [[ "$IGNORE_ALLOCATED" == "true" ]]; then
        total_cpu=$((${total_cpu}+${node_cpu_allocatable}))
        return
    fi
    
    #Current node cpu resource that is available for anything new to be installed.
    node_cpu_unrequested=$((${node_cpu_allocatable}-${node_cpu_request}))
    
    #Total cpu resource of the cluster that is available for anything new to be installed.
    total_cpu=$((${total_cpu}+${node_cpu_unrequested}))
}

check_available_cpu_and_memory() {
    
    #Fetch all the nodes for current cluster
    get_worker_node_list

    #For each node calculate cpu and memory resource.
    for node in ${all_node_list} ; do
        amd64Check=`${CLI} get node $node -o jsonpath='{.metadata.labels.kubernetes\.io/arch}'`
        taints=$(${CLI} get node "$node" -o=jsonpath='{.spec.taints[?(@.effect=="NoSchedule")].effect}' 2>/dev/null)

        if [[ "$amd64Check" == "amd64" && "$taints" != *"NoSchedule"* ]]; then
            node_describe=`${CLI} describe node ${node}`

            if [[ "$IGNORE_ALLOCATED" != "true" ]]; then
                node_resources=`echo "${node_describe}" | grep 'Allocatable' -A 20 -a | grep 'cpu|memory' -a -E | tr "\n" ' ' | tr -s ' '`
            else
                node_resources=`echo "${node_describe}" | grep 'Capacity' -A 20 -a | grep 'cpu|memory' -a -E | tr "\n" ' ' | tr -s ' '`
            fi

            #Calculate cpu resource available for each node
            calculate_cpu_unrequested

            #Calculate memory resource available for each node
            calculate_memory_unrequested
        fi
    done

    #100m CPU, 100 milliCPU, and 0.1 CPU are all the same. We calculate the cpu by dropping m hence we need to convert it back to 
    #vCPU = (total_cpu / 1000)
    total_cpu=$(awk "BEGIN{print $total_cpu / 1000}")
    #Converting the floating point to nearest integer.
    total_cpu=$( printf "%.0f" $total_cpu )
    
    #Converting the memory from MB to GB , 1GB = 1024MB
    total_memory_unrequested_GB=$(awk "BEGIN{print $total_memory / 1024}")
    #Converting the floating point to nearest integer
    total_memory_unrequested_GB=$( printf "%.0f" $total_memory_unrequested_GB )
    
}

analyze_resource_display() {

    ## Display for regular install

    # For production sized installs, if nodes are less than or equal to five, set large worker node as fail...
    # If nodes are b/w six and nine, then set as warning
    # If 10 or more, then set to pass
    if [[ $worker_node_count -le 5 ]]; then
        large_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
    elif [[ $worker_node_count -ge $NODE_COUNT_LARGE_4_5 ]]; then
        large_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
    else
        large_worker_node_count_string=`printf "$warn_color $worker_node_count $color_end\n"`
    fi
    
    if [[ $total_cpu -ge $VCPU_LARGE_4_5 ]]; then
        large_total_cpu_string=`printf "$pass_color $total_cpu $color_end\n"`
    else
        large_total_cpu_string=`printf "$fail_color $total_cpu $color_end\n"`
        CPU_LARGE="fail"
    fi

    if [[ $total_memory_unrequested_GB -ge $MEMORY_LARGE_4_5 ]]; then
        large_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
        large_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
        MEM_LARGE="fail"
    else
        large_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
        MEM_LARGE="fail"
    fi

    if [[ $worker_node_count -ge $NODE_COUNT_SMALL_4_5 ]]; then
        small_worker_node_count_string=`printf "$pass_color $worker_node_count $color_end\n"`
    else
        small_worker_node_count_string=`printf "$fail_color $worker_node_count $color_end\n"`
    fi
    
    if [[ $total_cpu -ge $VCPU_SMALL_4_5 ]]; then
        small_total_cpu_string=`printf "$pass_color $total_cpu $color_end\n"`
    else
        small_total_cpu_string=`printf "$fail_color $total_cpu $color_end\n"`
    fi
    
    if [[ $total_memory_unrequested_GB -ge $MEMORY_SMALL_4_5 ]]; then
        small_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
        small_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
    else
        small_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
    fi

    # With LAD -- starter memory
    if [[ $total_memory_unrequested_GB -ge $MEM_SMALL_LAD ]]; then
        WITH_LAD_small_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
        WITH_LAD_small_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
    else
        WITH_LAD_small_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
    fi

    # With LAD -- starter vcpu
    if [[ $total_cpu -ge $VCPU_SMALL_LAD ]]; then
        WITH_LAD_small_total_cpu_string=`printf "$pass_color $total_cpu $color_end\n"`
    else
        WITH_LAD_small_total_cpu_string=`printf "$fail_color $total_cpu $color_end\n"`
    fi

    # With LAD -- prod vcpu
    if [[ $total_cpu -ge $VCPU_LARGE_LAD ]]; then
        WITH_LAD_large_total_cpu_string=`printf "$pass_color $total_cpu $color_end\n"`
    else
        WITH_LAD_large_total_cpu_string=`printf "$fail_color $total_cpu $color_end\n"`
    fi

    # With LAD -- prod mem
    if [[ $total_memory_unrequested_GB -ge $MEM_LARGE_LAD ]]; then
        WITH_LAD_large_total_memory_unrequested_GB_string=`printf "$pass_color $total_memory_unrequested_GB $color_end\n"`
    elif [[ $total_memory_unrequested_GB -le 0 && "$unitNotSupported" -eq "true"  ]]; then
        WITH_LAD_large_total_memory_unrequested_GB_string=`printf "$fail_color DNE $color_end\n"`
    else
        WITH_LAD_large_total_memory_unrequested_GB_string=`printf "$fail_color $total_memory_unrequested_GB $color_end\n"`
    fi
}

calculateMaxInstances() {
    available_vcpu=$1
    available_memory=$2  
    required_vcpu=$3
    required_memory=$4  

    # Handle cases where required resources are zero to avoid division errors
    if [ "$required_vcpu" -eq 0 ] || [ "$required_memory" -eq 0 ]; then
        echo "0"
        return
    fi

    max_vcpu=$(awk "BEGIN {print int($available_vcpu / $required_vcpu)}")
    max_memory=$(awk "BEGIN {print int($available_memory / $required_memory)}")

    # Determine the limiting factor (find the minimum value)
    limiting_factor=$(awk "BEGIN {print ($max_vcpu < $max_memory) ? $max_vcpu : $max_memory}")

    # Output the limiting factor
    echo "$limiting_factor"
}

checkSmallOrLargeProfileInstall() {

    largeProfileNodeCheck=""
    
    echo
    startEndSection "Production Install Resources"
    log $INFO "Checking for cluster resources" ""
    echo

    check_available_cpu_and_memory
    
    analyze_resource_display
    
    log $INFO "==================================Resource Summary=====================================================" ""
    header=`printf "   %66s               |          %s      "  "vCPU" "Memory(GB)"`
    log $INFO "${header}" ""

    string=`printf "Production (HA) Base (available/required)                           [ %s/ %s ]              [ %s/ %s ]" "$large_total_cpu_string" "$VCPU_LARGE_4_5" "$large_total_memory_unrequested_GB_string" "$MEMORY_LARGE_4_5"`
    log $INFO "${string}" ""
    string=`printf "    (+ Log Anomaly Detection & Ticket Analysis)                [ %s/ %s ]              [ %s/ %s ]" "$WITH_LAD_large_total_cpu_string" "$VCPU_LARGE_LAD" "$WITH_LAD_large_total_memory_unrequested_GB_string" "$MEM_LARGE_LAD"`
    log $INFO "${string}" ""

    # Script need to output a message if memory cant be calculated. This script only supports Ki, Mi, Gi, Ti, Ei, Pi, bytes, and m.
    if [[ "$unitNotSupported" == "true" ]]; then
        log $WARNING "Cannot calculate memory because allocatable memory is using a unit that is not recognizable. This tool supports Ki, Gi, Mi, Ti, Ei, Pi, Bytes, and m" ""
    fi

    log $INFO "==================================Resource Summary=====================================================" ""
   

    # Get values for max_prod_instances
    max_prod_instances_WO_LAD=$(calculateMaxInstances $total_cpu $total_memory_unrequested_GB $VCPU_LARGE_4_5 $MEMORY_LARGE_4_5)
    max_prod_instances_LAD=$(calculateMaxInstances $total_cpu $total_memory_unrequested_GB $VCPU_LARGE_LAD $MEM_LARGE_LAD)

    if [[ ($total_cpu -ge $VCPU_LARGE_4_5) && ($total_memory_unrequested_GB -ge $MEMORY_LARGE_4_5)  ]] ; then
        log $INFO "Maximum instances of Base Production(HA): $max_prod_instances_WO_LAD" ""
        log $INFO "Maximum instances of Extended Production(HA): $max_prod_instances_LAD" ""

        LARGE_PROFILE_RES=$pass_msg
    else
        log $ERROR "Cluster does not have required resources available to install a production sized Cloud Pak for AIOps." ""
        echo
        LARGE_PROFILE_RES=$fail_msg
        startEndSection "Production Install Resources"
        return 1
    fi

    if [[ $worker_node_count -lt 3 ]]; then
        log $INFO "Less than three worker nodes detected. At least three worker nodes need to be active in order to be HA" ""
        log $INFO $worker_node_count
        LARGE_PROFILE_RES=$warning_msg
    fi 

    startEndSection "Production Install Resources"
    return 0
}

function printTable() {
    local name=$1
    local namespace=$2

    echo
    paste <(printf '%s\n' CLUSTERSERVICEVERSION "${name}") \
          <(printf '%s\n' NAMESPACE "${namespace}") \
    | column -ts $'\t'
    echo
}

function checkIfCertManagerPresent() {

    echo
    startEndSection "Cert Manager Check"
    log $INFO "Checking for Cert Manager operator" ""
    echo

    text=$(${CLI} get csv -A --no-headers=true -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,PHASE:.status.phase' | grep "cert-manager")
    result=$?
    if [[ "${result}" == "1" ]]; then
        log $ERROR "Cluster does not have a cert-manager operator installed." $fail_color
        CERTMANAGER_PRESENT=$fail_msg
        startEndSection "Cert Manager Check"
        return 1
    fi

    name=$(echo $text | awk '{print $1}')
    namespace=$(echo $text | awk '{print $2}')
    phase=$(echo $text | awk '{print $3}')
    if [[ "${phase}" == "Succeeded" ]]; then
        CERTMANAGER_PRESENT=$pass_msg
        log $INFO "Successfully functioning cert-manager found." ""
    elif [[ "${phase}" == "Pending" ]]; then
        CERTMANAGER_PRESENT=$pass_msg
        log $INFO "Pending cert-manager found." ""
        printTable $name $namespace
        startEndSection "Cert Manager Check"
        return 1
    else
        CERTMANAGER_PRESENT=$fail_msg
        log $ERROR "Cert Manager installation was unsuccessful." $fail_color
        startEndSection "Cert Manager Check"
        return 1
    fi

    printTable $name $namespace
    startEndSection "Cert Manager Check"
    return 0
}

function checkIfLicensingPresent() {

    echo
    startEndSection "Licensing Service Operator Check"
    log $INFO "Checking for Licensing Service operator" ""
    echo

    text=$(${CLI} get csv -A --no-headers=true -o=custom-columns='NAME:.metadata.name,NAMESPACE:.metadata.namespace,PHASE:.status.phase' | grep "licensing-operator")
    result=$?
    if [[ "${result}" == "1" ]]; then
        log $ERROR "Cluster does not have the licensing service operator installed." $fail_color
        LICENSING_PRESENT=$fail_msg
        startEndSection "Licensing Service Operator Check"
        return 1
    fi

    name=$(echo $text | awk '{print $1}')
    namespace=$(echo $text | awk '{print $2}')
    phase=$(echo $text | awk '{print $3}')
    if [[ "${phase}" == "Succeeded" ]]; then
        LICENSING_PRESENT=$pass_msg
        log $INFO "Successfully functioning licensing service operator found." ""
    elif [[ "${phase}" == "Pending" ]]; then
        LICENSING_PRESENT=$pass_msg
        log $INFO "Pending licensing service operator found." ""
        printTable $name $namespace
        startEndSection "Licensing Service Operator Check"
        return 1
    else
        LICENSING_PRESENT=$fail_msg
        log $ERROR "Unsuccessfully installed licensing service operator found." ""
        printTable $name $namespace
        startEndSection "Licensing Service Operator Check"
        return 1
    fi

    printTable $name $namespace
    startEndSection "Licensing Service Operator Check"
    return 0
}

function showMZNodes() {

    c=${1:-'NAME:.metadata.name,ZONE:.metadata.labels.topology\.kubernetes\.io/zone,REGION:.metadata.labels.topology\.kubernetes\.io/region'}
    [[ $# -gt 0 ]] && shift
    ${CLI} get nodes -l node-role.kubernetes.io/worker,kubernetes.io/arch=amd64 -o=custom-columns="$c" "$@"

}

function Multizone() {

    MZ_FLAG=""

    echo
    echo
    startEndSection "Multizone"

    if [[ "$LARGE_PROFILE_RES" != "$pass_msg" ]]; then
        log $ERROR "The cluster does not have enough resources for a production sized install. Please refer to the resource summary above." $fail_color
        MZ_RES=$fail_msg
        startEndSection "Multizone"
        return 1
    fi

    nzones=()
    zones=()
    node=()

    while read -r node zone _; do
        nodes+=("$node")
        nzones+=("$zone")
    done< <(showMZNodes "" --no-headers)

    while read l; do
        zones+=("$l")
    done< <(for i in "${nzones[@]}"; do echo $i; done| sort -u)
    uniqueZones=${#zones[@]}

    zones_CPU=()
    zones_Mem=()
    for z in "${zones[@]}"; do
        sum=0        
        nodes_in_zone=$(${CLI} get nodes -l "topology.kubernetes.io/zone=$z" | grep -v NAME | awk '{ print $1 }' | sort -V | tr "\n" ' ' | tr -s ' ')
        IFS=' ' read -r -a nodes_array <<< "$nodes_in_zone"
        
        for n in "${nodes_array[@]}"; do            
            node_describe=`${CLI} describe node ${n}`
            node_resources=`echo "${node_describe}" | grep 'Allocatable' -A 20 -a | grep 'cpu|memory' -a -E | tr "\n" ' ' | tr -s ' '`
                        
            #Calculate cpu resource available for each node
            calculate_cpu_unrequested

            #Calculate memory resource available for each node
            calculate_memory_unrequested
        done

        #100m CPU, 100 milliCPU, and 0.1 CPU are all the same. We calculate the cpu by dropping m hence we need to convert it back to 
        #vCPU = (total_cpu / 1000)
        total_cpu=$(awk "BEGIN{print $total_cpu / 1000}")
        #Converting the floating point to nearest integer.
        total_cpu=$( printf "%.0f" $total_cpu )

        #Converting the memory from MB to GB , 1GB = 1024MB
        total_memory_unrequested_GB=$(awk "BEGIN{print $total_memory / 1024}")
        #Converting the floating point to nearest integer
        total_memory_unrequested_GB=$( printf "%.0f" $total_memory_unrequested_GB )

        zc=$(printf "$z:$total_cpu")
        zm=$(printf "$z:$total_memory_unrequested_GB")

        zones_CPU+=($zc)
        zones_Mem+=($zm)
    done

    CPU_per_zone_large=$(( (($VCPU_LARGE_4_5 / $uniqueZones) + ($VCPU_LARGE_4_5 / (($uniqueZones - 1) * $uniqueZones))) + 2))
    for i in "${zones_CPU[@]}"; do
        zone="${i%%:*}"
        cpu="${i#*:}"

        
        if [[ "$cpu" -le  "$CPU_per_zone_large" ]]; then
            printf "$warn_color$WARNING $zone has $cpu CPU but at least $CPU_per_zone_large is required.$color_end\n"
            MZ_FLAG="true"
        else
            log $INFO "${zone} meets CPU requirements." ""
        fi
    done

    echo

    Mem_per_zone_large=$(( (($MEMORY_LARGE_4_5 / $uniqueZones) + ($MEMORY_LARGE_4_5 / (($uniqueZones - 1) * $uniqueZones))) + 2))
    for i in "${zones_Mem[@]}"; do
        zone="${i%%:*}"
        m="${i#*:}"
        
        if [[ "$m" -le  "$Mem_per_zone_large" ]]; then
            log $WARNING "$zone has ${m}G of Memory but at least ${Mem_per_zone_large}G is required." $warn_color
            MZ_FLAG="true"
        else
            log $INFO "${zone} meets Memory requirements." ""
        fi
    done
    
    if [[ "$MZ_FLAG" == "true" ]]; then
        MZ_RES=$warning_msg
        startEndSection "Multizone"
        return 0
    fi

    MZ_RES=$pass_msg
    log $INFO "Zones meet CPU and Memory requirements." $pass_color
    startEndSection "Multizone"

}

showSummary() {

    echo
    echo
    startEndSection "Prerequisite Checker Tool Summary"
    string=`printf "      [ %s ] Platform Version Check " "${OCP_VER_RES}"`
    printf "${string}\n" | tee -a $res_file

    if [[ "${isOpenshift}" == 0 ]]; then
        string=`printf "      [ %s ] Storage Provider\n" "${STORAGE_PROVIDER_RES}"`
        printf "${string}\n" | tee -a $res_file
    fi

    string=`printf "      [ %s ] Production (HA) Base Install Resources" "${LARGE_PROFILE_RES}"`
    printf "${string}\n" | tee -a $res_file

    string=`printf "      [ %s ] ResourceQuota Check" "${RQ_RES}"`
    printf "${string}\n" | tee -a $res_file

    if [[ "$SKIP_OPERATOR_CHECKS" != "true" ]]; then
        string=`printf "      [ %s ] Cert Manager Operator Installed" "${CERTMANAGER_PRESENT}"`
        printf "${string}\n" | tee -a $res_file
        string=`printf "      [ %s ] Licensing Service Operator Installed" "${LICENSING_PRESENT}"`
        printf "${string}\n" | tee -a $res_file
    fi

    if [[ "$SHOW_MULTIZONE" == "true" ]]; then
        string=`printf "      [ %s ] Zone CPU and Memory Requirements" "${MZ_RES}"`
        printf "${string}\n" | tee -a $res_file
    fi

    startEndSection "Prerequisite Checker Tool Summary"
}

startEndSection() {
    section=$1
    log $INFO "=================================${section}=================================" ""
}

storeResultsInConfigMap() {
    cleaned_file=$(mktemp)
    configmap_name="aiops-prereq"

    # Remove ANSI escape codes and save to a cleaned file
    sed -r 's/\x1B\[[0-9;]*[mK]//g' "$res_file" > "$cleaned_file"

    SCRIPT_OUTPUT=$(cat $cleaned_file)
   
    # Get the current date and time
    CURRENT_DATETIME=$(date +"%Y-%m-%d %H:%M:%S")

    echo ""
    echo "Storing results of prereq in configmap/$configmap_name"
    
    cat <<EOF | ${CLI} apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: $configmap_name
  namespace: $NAMESPACE
data:
  date: "${CURRENT_DATETIME}"
  script-output: |
$(echo "$SCRIPT_OUTPUT" | sed 's/^/    /')
EOF

    rm -f $res_file $cleaned_file
}

# This function checks if any resourcequotas are set within a given namespace. If
# so, it further checks if they exceed the hardware requirements.
checkResourceQuota() {
    local resourceQuotas
    local total_vcpu=0
    local total_memory=0
    local has_cpu_memory_quota=false

    echo ""
    startEndSection "ResourceQuota Check"

    # Check if NAMESPACE is set, if not fail check
    if [[ -z $NAMESPACE ]]; then
        log $ERROR "The -n option is not set." $fail_color
        RQ_RES=$fail_msg
        return 1
    fi

    # Fetch resource quotas (table format)
    resourceQuotas=$(${CLI} get resourcequota -n "${NAMESPACE}" --no-headers 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log $ERROR "Failed to access namespace ${NAMESPACE}." $fail_color
        startEndSection "ResourceQuota Check"
        RQ_RES=$fail_msg
        return 1
    fi

    # Check if no ResourceQuota exists
    if [ -z "${resourceQuotas}" ]; then
        log $INFO "No ResourceQuota found in namespace '${NAMESPACE}'." $pass_color
        startEndSection "ResourceQuota Check"
        RQ_RES=$pass_msg
        return 0
    fi

    # Extract and sum CPU limits
    total_vcpu=0
    while IFS= read -r line; do
        cpu_value=$(echo "$line" | grep -o 'limits.cpu:[^,]*' | awk -F'[:/ ]+' '{print $3}')

        if [[ -z "$cpu_value" ]]; then
            continue
        fi

        has_cpu_memory_quota=true  # Found at least one quota defining CPU/memory

        # Convert milliCPU to whole CPU if needed
        if [[ "$cpu_value" =~ m$ ]]; then
            cpu_value=${cpu_value%m}  # Remove 'm' suffix
            cpu_value=$((cpu_value / 1000))  # Convert milliCPU to cores
        fi

        total_vcpu=$((total_vcpu + cpu_value))
    done < <(echo "$resourceQuotas" | grep -o 'limits.cpu:[^,]*')

    # Extract and convert memory limits before summing
    total_memory=0
    while IFS= read -r line; do
        mem_value=$(echo "$line" | grep -o 'limits.memory:[^,]*' | awk -F'[:/ ]+' '{print $3}')

        if [[ -z "$mem_value" ]]; then
            continue
        fi

        has_cpu_memory_quota=true  # Found at least one quota defining CPU/memory

        # Convert to GiB
        if [[ "$mem_value" =~ Ki$ ]]; then
            mem_value=${mem_value%Ki}
            mem_value=$((mem_value / 1024 / 1024))  # Convert KiB to GiB
        elif [[ "$mem_value" =~ Mi$ ]]; then
            mem_value=${mem_value%Mi}
            mem_value=$((mem_value / 1024))  # Convert MiB to GiB
        elif [[ "$mem_value" =~ Gi$ ]]; then
            mem_value=${mem_value%Gi}  # Already in GiB, just strip 'Gi'
        else
            mem_value=0  # If extraction fails, default to 0
        fi

        total_memory=$((total_memory + mem_value))
    done < <(echo "$resourceQuotas" | grep -o 'limits.memory:[^,]*')

    # If no ResourceQuota defines CPU/memory, assume no restrictions
    if [[ "$has_cpu_memory_quota" == false ]]; then
        log $INFO "No CPU or Memory limits found in any ResourceQuota. Assuming no restrictions."
        RQ_RES=$pass_msg
        startEndSection "ResourceQuota Check"
        return 0
    fi

    log $INFO "ResourceQuotas found in namespace ${NAMESPACE} -- Summing limits..." ""
    log $INFO "Total vCPU Limit: ${total_vcpu} (Required: ${VCPU_LARGE_4_5})"
    log $INFO "Total Memory Limit: ${total_memory}Gi (Required: ${MEMORY_LARGE_4_5}Gi)"

    # Comparison
    if (( total_vcpu >= VCPU_LARGE_4_5 )) && (( total_memory >= MEMORY_LARGE_4_5 )); then
        if (( total_vcpu >= VCPU_LARGE_LAD )) && (( total_memory >= MEM_LARGE_LAD )); then
            log $INFO "ResourceQuota meets the minimum requirements for Base and Extended Production hardware requirements." $pass_color
            RQ_RES=$pass_msg
            startEndSection "ResourceQuota Check"
            return 0
        else
            log $WARNING "ResourceQuota meets minimum for Base Production hardware requirements. However, it did not meet the Extended requirements." $warn_color
            log $WARNING "If you do not intend on using Extended, you may ignore this warning"
            RQ_RES=$warning_msg
            startEndSection "ResourceQuota Check"
            return 0
        fi
    else
        log $ERROR "ResourceQuota does not meet the minimum requirements." $fail_color
        RQ_RES=$fail_msg
        startEndSection "ResourceQuota Check"
        return 1
    fi
}

function main {

    fail_found=0

    echo CLI: ${CLI}
    
    touch "$res_file" && echo "The file '$res_file' has been created."

    checkPlatformVersion || fail_found=1

    # Only check for storage providers is ocp based install
    if [[ "${isOpenshift}" == "0" ]]; then
        checkStorage || fail_found=1
    fi

    if [[ "${SKIP_OPERATOR_CHECKS}" != "true" ]]; then
        checkIfCertManagerPresent || fail_found=1
        checkIfLicensingPresent || fail_found=1
    fi

    checkSmallOrLargeProfileInstall || fail_found=1
    checkResourceQuota || fail_found=1

    if [[ "$SHOW_MULTIZONE" == "true" ]]; then
        Multizone
    fi

    showSummary
    storeResultsInConfigMap

    return $fail_found
}

main || exit 1