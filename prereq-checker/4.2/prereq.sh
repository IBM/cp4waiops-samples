#!/bin/bash
# © Copyright IBM Corp. 2020, 2023

set -eo pipefail

function display_help() {
    echo "**************************************** Usage ********************************************"
    echo
    echo " This script ensures that you have met the technical prerequisites for IBM Cloud Pak for AIOps version 4.2."
    echo
    echo " Before you run this script, you will need: "
    echo " 1. OpenShift (oc) command line interface (CLI)"
    echo " 2. Must be logged in to your cluster with oc login"
    echo " 3. Must be in the project (namespace) you have installed or will install the product in"
    echo
    echo " Usage:"
    echo " ./prereq.sh -h"
    echo "  -h Prints out the help message"
    echo " ./prereq.sh -o"
    echo "  -o Skips storageclass checks when using alternate storage providers"
    echo "*******************************************************************************************"
}

# Add options as needed
while getopts 'hsuo' opt; do
    case "$opt" in
	h)
	    display_help
	    exit 0
	    ;;
	o)
	    SKIP_STORAGE_CHECK="true"
	    ;;
    esac
done
shift "$(($OPTIND -1))"

function log () {
    local log_tracing_prefix=$1
    local log_message=$2
    local log_options=$3

    if [[ ! -z $log_options ]]; then
	echo $log_options "$log_tracing_prefix $log_message"
    else
	echo "$log_tracing_prefix $log_message"
    fi
}

function initialize() {

    ## Resource size for 4.2
    # These defaults are given in section 'IBM Cloud Pak for AIOps only Hardware requirement totals' under
    # 'Hardware requirements - IBM Cloud Pak for AIOps only' https://ibm.biz/aiops_hardware_420
    # Minimum resource values for small profile 4.2.x
    NODE_COUNT_SMALL_4_2=3
    VCPU_SMALL_4_2=62
    MEMORY_SMALL_4_2=140
    # Minimum resource values for large profile 4.2.x
    NODE_COUNT_LARGE_4_2=10
    VCPU_LARGE_4_2=162
    MEMORY_LARGE_4_2=372

    command="oc"
    notop=""
    adm="adm"
    UNIT_NOT_SUPPORTED="false"

    # Tracing prefixes
    INFO="[INFO]"
    WARNING="[WARNING]"
    ERROR="[ERROR]"

    # For Summary method
    REQUIRED_OCP_VERSION="4.12"    
    OCP_VER_RES=""
    STORAGE_PROVIDER_RES=""
    PROFILE_RES=""
    PS_RES=""

    warn_color="\x1b[33m"
    fail_color="\x1b[31m"
    pass_color="\e[32m"
    color_end="\x1b[0m"

    fail_msg=$(printf "$fail_color FAIL $color_end")
    pass_msg=$(printf "$pass_color PASS $color_end\n")
    warning_msg=$(printf "$warn_color WARNING $color_end")
    skip_msg=$(printf "$warn_color SKIP $color_end")

    # array to hold all storage check results
    STORAGE_CHECK_RES=()

    # global vars pulled out of functions
    JOB_NAME="cp4waiops-entitlement-key-test-job"
    SECRET_NAME="ibm-entitlement-key"
}

# Verify oc is installed & we are logged into the cluster
function verifyOC() {
    if ! [ -x "$(command -v oc)" ]; then
	log $ERROR "oc CLI is not installed.  Please install the oc CLI and try running the script again."
	exit 1
    fi

    ${command} project
    if [ $? -gt 0 ]; then
	log $ERROR "oc login required.  Please login to the cluster and try running the script again."
	exit 1
    fi
}

function evaluateGlobalVariables() {
    ENTITLEMENT_SECRET=$(${command} get secret | grep $SECRET_NAME)
}

# This function checks to see if user's OCP version meets our requirements by checking if 
# substring "${REQUIRED_OCP_VERSION}" is in variable OCP_VER.
# global variable modification:
# OCP_VER_RES
function checkOCPVersion {
    
    local OCP_VER=$(${command} get clusterversion version -o=jsonpath='{.status.desired.version}')

    local ODF_STORAGE=$(${command} get storageclass ocs-storagecluster-cephfs --ignore-not-found=true)

    startEndSection "Openshift Container Platform Version Check"
    log $INFO "Checking OCP Version. Compatible Versions of OCP is v${REQUIRED_OCP_VERSION}.x "
    
    if [[ $OCP_VER == *"${REQUIRED_OCP_VERSION}"* ]]; then

	log $INFO "OCP version $OCP_VER is compatible" 

	OCP_VER_RES=$pass_msg
	startEndSection "Openshift Container Platform Version Check"
	return 0
    else
	printf " $fail_color $ERROR OCP Version is incompatible. Required Version: v${REQUIRED_OCP_VERSION}.x $color_end\n"
	log $ERROR "Your Version: v$OCP_VER"
	echo
	OCP_VER_RES=$fail_msg
	startEndSection "Openshift Container Platform Version Check"
	return 1
    fi
}

# Check for entitlement or global pull secret
function checkEntitlementSecret () {
    
    local GLOBAL_PULL_SECRET=$(${command} get secret pull-secret -n openshift-config)

    echo
    startEndSection "Entitlement Pull Secret"
    log $INFO "Checking whether the Entitlement secret or Global pull secret is configured correctly."
    

    if [[ -z $ENTITLEMENT_SECRET && -z $GLOBAL_PULL_SECRET ]] ; then
	printf " $fail_color $ERROR Ensure that you have either a '$SECRET_NAME' secret or a global pull secret 'pull-secret' configured in the namespace 'openshift-config'. $color_end\n"
	PS_RES=$fail_msg
	startEndSection "Entitlement Pull Secret"
	return 1
    else
	createTestJob
    fi
}

function createTestJob () {
    # Use return the word count of "oc get jobs $JOB_NAME"
    wc=$(${command} get job $JOB_NAME --no-headers=true --ignore-not-found=true | wc -l)

    log $INFO "Checking if the job '$JOB_NAME' already exists."
    if [ "${wc}" -gt 0  ]; then
	${command} delete job $JOB_NAME
	sleep 10
    else
	log $INFO "The job with name '$JOB_NAME' was not found, so moving ahead and creating it."
    fi

    if [[ $ENTITLEMENT_SECRET ]] ; then
	log $INFO "Creating the job '$JOB_NAME' "
	exec 3>&2
	exec 2> /dev/null
	cat <<EOF | ${command} apply -f -
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cp4waiops-entitlement-key-test-job
    spec:
      parallelism: 1
      completions: 1
      template:
        metadata:
          name: pi
        spec:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                    - key: kubernetes.io/arch
                      operator: In
                      values:
                        - amd64
          imagePullSecrets:
          - name: ibm-entitlement-key
          containers:
          - name: testimage
            image: cp.icr.io/cp/cp4waiops/ai-platform-api-server@sha256:07602b8936935a571e6585e5e6d416999f14a1865156585ae5a8a62b5dd93fb5
            imagePullPolicy: Always
            command: [ "echo", "SUCCESS" ]
          restartPolicy: OnFailure
EOF
	exec 2>&3
    else
	log $INFO "Creating the job '$JOB_NAME' "
	exec 3>&2
	exec 2> /dev/null
	cat <<EOF | ${command} apply -f -
    apiVersion: batch/v1
    kind: Job
    metadata:
      name: cp4waiops-entitlement-key-test-job
    spec:
      parallelism: 1
      completions: 1
      template:
        metadata:
          name: pi
        spec:
          affinity:
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                    - key: kubernetes.io/arch
                      operator: In
                      values:
                        - amd64
          containers:
          - name: testimage
            image: cp.icr.io/cp/cp4waiops/ai-platform-api-server@sha256:07602b8936935a571e6585e5e6d416999f14a1865156585ae5a8a62b5dd93fb5
            imagePullPolicy: Always
            command: [ "echo", "SUCCESS" ]
          restartPolicy: OnFailure
EOF
	exec 2>&3
    fi
    sleep 3
    checkEntitlementCred
}

function checkEntitlementCred () {

    log $INFO "Verifying if the job '$JOB_NAME' completed successfully.."    
    
    local SLEEP_LOOP=5
    local image_pull_status_flag=""
    local POD_NAME=$(${command} get pod -o name | grep $JOB_NAME)
    local phase_status=""
    local container_status=""
    local logs_status=""

    if [[ ! -z $POD_NAME ]];then
	local LOOP_COUNT=0
	while [ $LOOP_COUNT -lt 25 ]
	do
            phase_status=$(${command} get $POD_NAME -o jsonpath='{.status.phase}')
            if [[ $phase_status == "Succeeded" ]];then
		container_status=$(${command} get $POD_NAME -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}')
		if [[ "$container_status" != "ErrImagePull" && "$container_status" != "ImagePullBackOff" ]]; then
		    if [[ "$container_status" == "Completed" ]]; then
			image_pull_status_flag="true"
			break
		    fi
		fi
            elif [[ $phase_status == "Pending" ]];then
		container_status=$(${command} get $POD_NAME -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}')
		if [[ "$container_status" == "ErrImagePull" || "$container_status" == "ImagePullBackOff" ]]; then
		    image_pull_status_flag="false" 
		fi
            fi
            # log $INFO "Waiting for $SLEEP_LOOP, and checking the job '$JOB_NAME' status again"
            sleep $SLEEP_LOOP
            LOOP_COUNT=$(expr $LOOP_COUNT + 1)
	done
    else
	printf " $fail_color $ERROR Some error occured while '$JOB_NAME' job creation for testing entitlement secret configuration. $color_end\n"
	startEndSection "Entitlement Pull Secret"
	return 1
    fi
    
    #Checking the job pod logs, where we chose to just print 'SUCCESS' message.
    if [[ "$image_pull_status_flag" == "true" ]]; then
	logs_status=$(${command} logs $POD_NAME)
	if [[ $logs_status == "SUCCESS"  ]];then
            log $INFO "SUCCESS! Entitlement secret is configured correctly."
            PS_RES=$pass_msg
	else
            printf "$fail_color $ERROR Some error occured in validating job '$JOB_NAME' logs, error validating the entitlement secret $color_end\n"
            PS_RES=$fail_msg
	fi
    else
	PS_RES=$fail_msg
	printf "$fail_color $ERROR The pod '$POD_NAME' failed with container_status='$container_status' $color_end\n"
	printf "$fail_color $ERROR Entitlement secret is not configured correctly. $color_end\n"
    fi
    
    #cleaning the job in case if script reaches here.
    ${command} delete job $JOB_NAME
    startEndSection "Entitlement Pull Secret"
}

function checkAllowVolumeExpansion() {
    local storageclass=$1
    
    local volumeExpansionEnabled=$(${command} get storageclass $storageclass -o=jsonpath='{.allowVolumeExpansion}')
    if [[ "${volumeExpansionEnabled}" != "true" ]]; then
	return 1
    fi

    return 0
}

function checkIBMSpectrum {
    local OCP_VER=""
    local IBM_SPEC_VE=""
    printf "\nChecking if IBM Storage Fusion is configured properly...\n"

    # Check OCP version is ${REQUIRED_OCP_VERSION}
    OCP_VER=$(${command} get clusterversion version -o=jsonpath='{.status.desired.version}')
    if [[ "$OCP_VER" == *"${REQUIRED_OCP_VERSION}"* ]]; then
	# If it meets the ocp version requirement... check if ibm-spectrum-scale-sc storageclass has volume expansion enabled
	IBM_SPEC_VE=$(checkAllowVolumeExpansion ibm-spectrum-scale-sc)
	if [[ "$?" == "1" ]]; then
	    printf "${fail_color}${ERROR} StorageClass ibm-spectrum-scale-sc does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	    STORAGE_CHECK_RES+=("fail")
	    return 1
	fi
	
	STORAGE_CHECK_RES+=("pass")
	printf "IBM Storage Fusion looks fine."
	return 0
    else
	# OCP ${REQUIRED_OCP_VERSION} was not found... fail this check
	printf "${fail_color}${ERROR}If you intend to use Storage Fusion with AIOPS 4.2, you must have ${REQUIRED_OCP_VERSION} $color_end\n"
	log $INFO "See Readme for more info about this."
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi
}

function checkODF {
    local odfPods=$1
    local podStatus=""
    local odfStorageClasses=()
    local odf_ve_flag="false"
    local ve_check=""
    
    printf "\nChecking Openshift Data Foundation Configuration...\n"
    printf "Verifying if Red Hat Openshift Data Foundation pods are in \"Running\" or \"Completed\" status\n"

    for p in "${odfPods[@]}"; do
	podStatus=$(${command} get pod $p -n openshift-storage -o jsonpath='{.status.phase}')
	if [[ "$podStatus" == "Running" || "$podStatus" == "Succeeded" ]]; then
	    continue
	else
	    printf "$fail_color $ERROR Pod in openshift-storage project namespace found not \"Running\" or \"Completed\": $p $color_end\n"
	    STORAGE_CHECK_RES+=("fail")
	    return 1
	fi
    done

    log $INFO "Pods in openshift-storage project are \"Running\" or \"Completed\""

    odfStorageClasses=("ocs-storagecluster-ceph-rbd" "ocs-storagecluster-cephfs")
    for s in "${odfStorageClasses[@]}"; do
	${command} get storageclass $s > /dev/null 2>&1
	if [[ "$?" == "0" ]]; then
	    log $INFO "$s exists."
	else
	    printf "$warn_color $WARNING $s does not exist. $color_end\n"
	    STORAGE_CHECK_RES+=("warn")
	    return 1
	fi
    done

    # Check if each ODF StorageClass has allowVolumeExpansion enabled. If not set the ODF_VE_FLAG to true

    for s in "${ODF_STORAGECLASSES[@]}"; do
	ve_check=$(checkAllowVolumeExpansion $s)
	if [[ "$?" == "1" ]]; then
	    printf " $fail_color $ERROR StorageClass $s does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	    odf_ve_flag="true"
	fi
    done

    # If odf_ve_flag is true, then that means a sc has been found that has allowvolumeexpansion disabled or missing. In that case, we'll go ahead and
    # output a failure for this check
    if [[ "$odf_ve_flag" == "true" ]]; then
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi

    STORAGE_CHECK_RES+=("pass")
    return 0
}


function checkPortworx {
    local portworx_warning="false"
    local portworx_fs=""
    local portworx_block=""
    printf "\nChecking Portworx Configuration...\n"

    printf "Checking for storageclass \"portworx-fs\"...\n"
    ${command} get storageclass portworx-fs > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
	log $INFO "StorageClass \"portworx-fs\" exists."
    else
	portworx_warning="true"
	echo
	log $WARNING "StorageClass \"portworx-fs\" does not exist. See \"Portworx Storage\" section in https://ibm.biz/storage_consideration_420 for details.\n"
    fi

    printf "Checking for storageclass \"portworx-aiops\"...\n"
    ${command} get storageclass portworx-aiops > /dev/null 2>&1
    if [[ "$?" == "0" ]]; then
	log $INFO "StorageClass \"portworx-aiops\" exists."
    else
	portworx_warning="true"
	echo
	log $WARNING "StorageClass \"portworx-aiops\" does not exist. See \"Portworx Storage\" section in https://ibm.biz/storage_consideration_420 for details.\n"
    fi
    
    portworx_fs=$(checkAllowVolumeExpansion portworx-aiops)
    if [[ "$?" == "1" ]]; then
	echo
	printf " $fail_color $ERROR StorageClass portworx-aiops does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi

    portworx_block=$(checkAllowVolumeExpansion portworx-fs)
    if [[ "$?" == "1" ]]; then
	echo
	printf " $fail_color $ERROR StorageClass portworx-fs does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi
    
    if [[ "$portworx_warning" == "false" ]]; then
	STORAGE_CHECK_RES+=("pass")
    else
	STORAGE_CHECK_RES+=("warn")
    fi
    
    return 0
}

function checkIBMCFileGoldGidStorage {
    printf "Checking if IBM Cloud Storage is configured properly...\n"
    local file=""
    local block=""
    local ve_block=""
    local ve_file=""

    file=$(${command} get storageclass ibmc-file-gold-gid --ignore-not-found=true)
    block=$(${command} get storageclass ibmc-block-gold --ignore-not-found=true)

    if [[ "$file" == "" || "$block" == "" ]]; then
	printf "$fail_color $ERROR Both ibmc-block-gold and ibmc-file-gold-gid need to exist to use IBM Cloud Storage. See \"Storage\" section in https://ibm.biz/storage_consideration_420 for details. $color_end\n"
	STORAGE_CHECK_RES+=("fail")
	return 1 
    fi

    ve_block=$(checkAllowVolumeExpansion ibmc-block-gold)
    if [[ "$?" == "1" ]]; then
	printf " $fail_color $ERROR StorageClass ibmc-block-gold does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi

    ve_file=$(checkAllowVolumeExpansion ibmc-file-gold-gid)
    if [[ "$?" == "1" ]]; then
	printf " $fail_color $ERROR StorageClass ibmc-file-gold-gid does not have allowedVolumeExpansion enabled. This is required for all large profile installs and strongly recommended for small profile installs. See \"Storage Class Requirements\" section in https://ibm.biz/storage_consideration_420 for details.$color_end\n"
	STORAGE_CHECK_RES+=("fail")
	return 1
    fi

    STORAGE_CHECK_RES+=("pass")
}

function checkStorage {
    # Initialize an empty array. If storage provider is found, append the name as an element...
    local storageFound=()
    local ibm_spec_fusion=""
    local storage_cluster=""
    local odf_pods=""
    local ibmc_file_gold_gid=""
    local ibmc_block_gold_gid=""

    if [[ $SKIP_STORAGE_CHECK == "true" ]]; then
	echo
	startEndSection "Storage Provider"
	log $INFO "Skipping storage provider check"
	startEndSection "Storage Provider"
	STORAGE_PROVIDER_RES=$skip_msg
	return 0
    fi

    echo
    startEndSection "Storage Provider"
    log $INFO "Checking storage providers"

    # Check for Storage Fusion
    ibm_spec_fusion=$(${command} get storageclass ibm-spectrum-scale-sc --ignore-not-found=true)
    if [[ "$ibm_spec_fusion" != "" ]]; then
	echo
	log $INFO "A storage class related to Storage Fusion was found."
	storageFound+=("ibm-spec")
    else
	log $INFO "No IBM Storage Fusion Found... Skipping configuration check."
    fi

    # Check for any hints portworx is deployed. In this scenario, we look for any storage clusters that are deployed in all namespaces. Then
    # we check if the keyword "Running"
    storage_cluster=$(${command} get storagecluster.core.libopenstorage.org -A --ignore-not-found=true --no-headers=true 2>>/dev/null)
    if [[ "$storage_cluster" == *"Running"* || "$storage_cluster" == *"Online"* ]]; then
	log $INFO "Portworx Found. StorageCluster instance in \"Running\" or \"Online\" status found."
	storageFound+=("portworx")
    else
	echo
	log $INFO "No Portworx StorageClusters found with \"Running\" or \"Online\" status. Skipping configuration check for Portworx."
    fi

    # Check for ODF...
    odf_pods=($(${command} get pods -n openshift-storage --no-headers=true | awk '{print $1}'))
    if [[ "$odf_pods" == "" ]]; then
	echo
	log $INFO "Openshift Data Foundation not running. Skipping configuration check for ODF."
    else
	log $INFO "Openshift Data Foundation found."
	storageFound+=("odf")
    fi

    # Check for IBM Cloud Storage...
    ibmc_file_gold_gid=$(${command} get storageclass ibmc-file-gold-gid --ignore-not-found=true)
    ibmc_block_gold_gid=$(${command} get storageclass ibmc-block-gold --ignore-not-found=true)
    if [[ "$ibmc_file_gold_gid" != "" || "$ibmc_block_gold_gid" != ""  ]]; then
	echo
	log $INFO "IBM Cloud Storage found."
	storageFound+=("ibmc")
    else
	log $INFO "No IBM Cloud Storage found... Skipping configuration check for IBM Cloud Storage Check."
    fi

    # If no storageProviders were found, print an error...
    if [ ${#storageFound[@]} -eq 0 ]; then
	STORAGE_PROVIDER_RES=$fail_msg
	printf "$fail_color $ERROR At least one of the four Storage Providers are required$color_end\n"
	printf "$fail_color $ERROR The supported Storage Providers are Portworx, Openshift Data Foundation, IBM Cloud Storage for ROKS, or IBM Spectrum Fusion/IBM Spectrum Scale Container Native. See https://ibm.biz/storage_consideration_420 for details.$color_end\n"
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
	checkODF $odf_pods
    fi

    # Check the storageFound Array if portworx was found. If so, run the function to check for the expected storgeclasses
    if [[ " ${storageFound[*]} " =~ "portworx" ]]; then
	checkPortworx
    fi

    if [[ " ${storageFound[*]} " =~ "ibm-spec" ]]; then
	checkIBMSpectrum
    fi

    # Check if there are any failing configurations, if so we can automatically send a failure result for this check
    if [[ "${STORAGE_CHECK_RES[*]}" =~ "fail" ]]; then
	STORAGE_PROVIDER_RES=$fail_msg
	log $INFO "One or more errors found when checking for Storage Providers."
	startEndSection "Storage Provider"
	return 1
    fi

    # If we did not find any strings with "fail", then we can assume we assume we only have warnings and/or passes. First, check if
    # there are any warnings. If found we can warn the user there was one warning message that was found. Otherwise, show "Pass" for overall 
    # storage check.
    if [[ "${STORAGE_CHECK_RES[*]}" =~ "warn"  ]]; then
	STORAGE_PROVIDER_RES=$warning_msg
	log $INFO "One of more warnings found when checking for Storage Providers."
    else
	STORAGE_PROVIDER_RES=$pass_msg
	log $INFO "No warnings or failures found when checking for Storage Providers."
    fi

    startEndSection "Storage Provider"
    return 0 
}

# global variables:
# WORKER_NODE_COUNT

#unused:
# top
# MASTER_NODE_COUNT
# TOTAL_NODES
get_worker_node_list() {
    local describe=""
    local noSchedule=""

    if [ -z "${ALL_NODE_LIST}" ] ; then
	ALL_NODE_LIST=`${command} get nodes | grep -v NAME | awk '{ print $1 }' | sort -V | tr "\n" ' ' | tr -s ' '`
    fi	
    
    if [ -z ${notop} ] ; then
	top=`${command} ${adm} top nodes`
    fi
    
    for node in ${ALL_NODE_LIST} ; do
	describe=`${command} describe node ${node} 2> /dev/null`
	noSchedule=`echo ${describe} | grep NoSchedule`
	if [ -z "${noSchedule}" ] ; then
            WORKER_NODE_COUNT=$((${WORKER_NODE_COUNT}+1))
	else
            MASTER_NODE_COUNT=$((${MASTER_NODE_COUNT}+1))
	fi
	TOTAL_NODES=$((${TOTAL_NODES}+1)) 
    done

}

# modifies global variable:
# UNIT_NOT_SUPPORTED
function convert_memory_in_MB() {

    local node_mem_raw=$1
    local node_mem_without_unit=$2
    local KiToMB=""
    local MiToMB=""
    local GiToMB=""
    local TiToMB=""
    local PiToMB=""
    local EiToMB=""
    local mem_MB=""

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
	UNIT_NOT_SUPPORTED="true"
    fi

    echo "${mem_MB}"
}

function convert_cpu_unit() {

    local cpu_before_conversion=$1
    
    local converted_cpu=0
    if [[ "${cpu_before_conversion}" =~ "m" ]] ; then
	converted_cpu=$(echo ${cpu_before_conversion} | sed 's/[^0-9]*//g')
    else
	converted_cpu=$((${cpu_before_conversion}*1000))
    fi
    
    echo "${converted_cpu}"
}
# global variables:
#TOTAL_MEMORY_UNREQUESTED_MB
function calculate_memory_unrequested() {

    local node_mem_raw_Ki=""
    local node_mem_allocatable_Ki=""
    local node_mem_allocatable_MB=""
    local node_mem_request_raw=""
    local node_mem_request_without_unit=""
    local node_mem_request_MB=""
    
    #Allocatable raw memory of a node with unit value. eg 30998112Ki
    node_mem_raw_Ki=$1
    node_mem_allocatable_Ki=$(echo ${node_mem_raw_Ki} | sed 's/[^0-9]*//g')


    #Allocatable memory converted in MB
    node_mem_allocatable_MB=$(convert_memory_in_MB $node_mem_raw_Ki $node_mem_allocatable_Ki)

    #Requested memory for current node eg: 26958Mi or 30998112Ki
    node_mem_request_raw=$2
    node_mem_request_without_unit=$(echo ${node_mem_request_raw} | sed 's/[^0-9]*//g')


    #Requested memory converted to MB
    node_mem_request_MB=$(convert_memory_in_MB $node_mem_request_raw $node_mem_request_without_unit)
    
    #Available memory for new install in MB
    node_memory_unrequested_MB=$(awk "BEGIN{print $node_mem_allocatable_MB - $node_mem_request_MB}")

    echo $node_memory_unrequested_MB
}

# global variables:
# TOTAL_CPU_UNREQUESTED
function calculate_cpu_unrequested() {

    local node_cpu_raw=""
    local node_cpu_request=""
    local node_cpu_allocatable=""
    local converted_node_cpu_request=""
    local node_cpu_unrequested=""

    #Allocatable raw cpu from node resource
    node_cpu_raw=$1
    
    #Requested cpu resource from node resource
    node_cpu_request=$2

    node_cpu_allocatable=$(convert_cpu_unit $node_cpu_raw)
    
    converted_node_cpu_request=$(convert_cpu_unit $node_cpu_request)
    
    #Current node cpu resource that is available for anything new to be installed.
    node_cpu_unrequested=$((${node_cpu_allocatable}-${converted_node_cpu_request}))

    echo $node_cpu_unrequested
}

# global variables:
# TOTAL_CPU_UNREQUESTED
# TOTAL_MEMORY_UNREQUESTED_GB
function check_available_cpu_and_memory() {
    local node_cpu_request=""
    local node_cpu_raw=""
    local node_describe=""
    local node_resources=""
    TOTAL_CPU_UNREQUESTED=0
    TOTAL_MEMORY_UNREQUESTED_MB=0
    
    #Fetch all the nodes for current cluster
    get_worker_node_list
    echo "WORKER_NODE_COUNT"
    echo $WORKER_NODE_COUNT

    #For each node calculate cpu and memory resource.
    for node in ${ALL_NODE_LIST} ; do
	node_describe=$(${command} describe node ${node})
	node_resources=$(echo "${node_describe}" | grep 'Allocatable' -A 6 -a | grep -E 'cpu|memory' -a | tr "\n" ' ' | tr -s ' ')

	node_cpu_raw=$(echo ${node_resources} | awk '{ print $2 }')

	node_cpu_request=$(echo "${node_describe}" | grep 'cpu ' -a | tail -1 | awk '{ print $2 }')

	node_mem_raw_Ki=$(echo ${node_resources} | awk '{ print $4 }')

	node_mem_request_raw=$(echo "${node_describe}" | grep 'memory ' -a | tail -1 | awk '{ print $2 }')
	
	#Calculate cpu resource available for each node
	node_cpu_unrequested=$(calculate_cpu_unrequested $node_cpu_raw $node_cpu_request)

	TOTAL_CPU_UNREQUESTED=$(( ${TOTAL_CPU_UNREQUESTED} + ${node_cpu_unrequested} ))

	#Calculate memory resource available for each node
	node_memory_unrequested_MB=$(calculate_memory_unrequested $node_mem_raw_Ki $node_mem_request_raw)
	
	TOTAL_MEMORY_UNREQUESTED_MB=$(awk "BEGIN{print $TOTAL_MEMORY_UNREQUESTED_MB + $node_memory_unrequested_MB}" )

    done
    
    #100m CPU, 100 milliCPU, and 0.1 CPU are all the same. We calculate the cpu by dropping m hence we need to convert it back to 
    #vCPU = (total_cpu_unrequested / 1000)
    TOTAL_CPU_UNREQUESTED=$(awk "BEGIN{print $TOTAL_CPU_UNREQUESTED / 1000}")
    #Converting the floating point to nearest integer.
    TOTAL_CPU_UNREQUESTED=$( printf "%.0f" $TOTAL_CPU_UNREQUESTED )
    
    #Converting the memory from MB to GB , 1GB = 1024MB
    TOTAL_MEMORY_UNREQUESTED_GB=$(awk "BEGIN{print $TOTAL_MEMORY_UNREQUESTED_MB / 1024}")
    #Converting the floating point to nearest integer
    TOTAL_MEMORY_UNREQUESTED_GB=$( printf "%.0f" $TOTAL_MEMORY_UNREQUESTED_GB )
}

# global variables
# too many to count, basically all of them
function analyze_resource_display() {

    ## Display for regular install
    if [[ $WORKER_NODE_COUNT -ge $NODE_COUNT_LARGE_4_2 ]]; then
	LARGE_WORKER_NODE_COUNT_STRING=$(printf "$pass_color $WORKER_NODE_COUNT $color_end\n")
    else
	LARGE_WORKER_NODE_COUNT_STRING=$(printf "$fail_color $WORKER_NODE_COUNT $color_end\n")
    fi
    
    if [[ $TOTAL_CPU_UNREQUESTED -ge $VCPU_LARGE_4_2 ]]; then
	LARGE_TOTAL_CPU_UNREQUESTED_STRING=$(printf "$pass_color $TOTAL_CPU_UNREQUESTED $color_end\n")
    else
	LARGE_TOTAL_CPU_UNREQUESTED_STRING=$(printf "$fail_color $TOTAL_CPU_UNREQUESTED $color_end\n")
    fi

    if [[ $TOTAL_MEMORY_UNREQUESTED_GB -ge $MEMORY_LARGE_4_2 ]]; then
	LARGE_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$pass_color $TOTAL_MEMORY_UNREQUESTED_GB $color_end\n")
    elif [[ $TOTAL_MEMORY_UNREQUESTED_GB -le 0 && "$UNIT_NOT_SUPPORTED" -eq "true"  ]]; then
	LARGE_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$fail_color DNE $color_end\n")
    else
	LARGE_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$fail_color $TOTAL_MEMORY_UNREQUESTED_GB $color_end\n")
    fi

    if [[ $WORKER_NODE_COUNT -ge $NODE_COUNT_SMALL_4_2 ]]; then
	SMALL_WORKER_NODE_COUNT_STRING=$(printf "$pass_color $WORKER_NODE_COUNT $color_end\n")
    else
	SMALL_WORKER_NODE_COUNT_STRING=$(printf "$fail_color $WORKER_NODE_COUNT $color_end\n")
    fi
    
    if [[ $TOTAL_CPU_UNREQUESTED -ge $VCPU_SMALL_4_2 ]]; then
	SMALL_TOTAL_CPU_UNREQUESTED_STRING=$(printf "$pass_color $TOTAL_CPU_UNREQUESTED $color_end\n")
    else
	SMALL_TOTAL_CPU_UNREQUESTED_STRING=$(printf "$fail_color $TOTAL_CPU_UNREQUESTED $color_end\n")
    fi
    
    if [[ $TOTAL_MEMORY_UNREQUESTED_GB -ge $MEMORY_SMALL_4_2 ]]; then
	SMALL_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$pass_color $TOTAL_MEMORY_UNREQUESTED_GB $color_end\n")
    elif [[ $TOTAL_MEMORY_UNREQUESTED_GB -le 0 && "$UNIT_NOT_SUPPORTED" -eq "true"  ]]; then
	SMALL_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$fail_color DNE $color_end\n")
    else
	SMALL_TOTAL_MEMORY_UNREQUESTED_GB_STRING=$(printf "$fail_color $TOTAL_MEMORY_UNREQUESTED_GB $color_end\n")
    fi
}

function checkSmallOrLargeProfileInstall() {

    local header=""
    local string=""
    
    echo
    startEndSection "Small or Large Profile Install Resources"
    log $INFO "Checking for cluster resources"
    echo
    check_available_cpu_and_memory
    
    analyze_resource_display
    
    log $INFO "==================================Resource Summary====================================================="
    header=$(printf "   %40s   |      %s      |     %s" "Nodes" "vCPU" "Memory(GB)")
    log $INFO "${header}"
    string=$(printf "Small profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$SMALL_WORKER_NODE_COUNT_STRING" "$NODE_COUNT_SMALL_4_2" "$SMALL_TOTAL_CPU_UNREQUESTED_STRING" "$VCPU_SMALL_4_2" "$SMALL_TOTAL_MEMORY_UNREQUESTED_GB_STRING" "$MEMORY_SMALL_4_2")
    log $INFO "${string}"
    string=$(printf "Large profile(available/required)  [ %s/ %s ]   [ %s/ %s ]       [ %s/ %s ]" "$LARGE_WORKER_NODE_COUNT_STRING" "$NODE_COUNT_LARGE_4_2" "$LARGE_TOTAL_CPU_UNREQUESTED_STRING" "$VCPU_LARGE_4_2" "$LARGE_TOTAL_MEMORY_UNREQUESTED_GB_STRING" "$MEMORY_LARGE_4_2")
    log $INFO "${string}"
    
    # Script need to output a message if memory cant be calculated. This script only supports Ki, Mi, Gi, Ti, Ei, Pi, bytes, and m.
    if [[ "$UNIT_NOT_SUPPORTED" == "true" ]]; then
	log $WARNING "Cannot calculate memory because allocatable memory is using a unit that is not recognizable. This tool supports Ki, Gi, Mi, Ti, Ei, Pi, Bytes, and m"
    fi

    log $INFO "==================================Resource Summary====================================================="
    
    if [[ ($WORKER_NODE_COUNT -ge $NODE_COUNT_LARGE_4_2) && ($TOTAL_CPU_UNREQUESTED -ge $VCPU_LARGE_4_2) && ($TOTAL_MEMORY_UNREQUESTED_GB -ge $MEMORY_LARGE_4_2)  ]] ; then
	log $INFO "Cluster currently has resources available to create a large profile of Cloud Pak for AIOps"
    elif [[ $WORKER_NODE_COUNT -ge $NODE_COUNT_SMALL_4_2 && ($TOTAL_CPU_UNREQUESTED -ge $VCPU_SMALL_4_2) && ($TOTAL_MEMORY_UNREQUESTED_GB -ge $MEMORY_SMALL_4_2) ]] ; then
	log $INFO "Cluster currently has resources available to create a small profile of Cloud Pak for AIOps"
	echo
    else
	log $ERROR "Cluster does not have required resources available to install Cloud Pak for AIOps."
	echo
	PROFILE_RES=$fail_msg
	startEndSection "Small or Large Profile Install Resources"
	return 1
    fi
    PROFILE_RES=$pass_msg
    startEndSection "Small or Large Profile Install Resources"
}

function showSummary() {
    local string=""
    echo
    echo
    startEndSection "Prerequisite Checker Tool Summary"
    string=$(printf "      [ %s ] Openshift Container Platform Version Check " "${OCP_VER_RES}")
    printf "${string}\n"
    string=$(printf "      [ %s ] Entitlement Pull Secret" "${PS_RES}")
    printf "${string}\n"
    string=$(printf "      [ %s ] Storage Provider\n" "${STORAGE_PROVIDER_RES}")
    printf "${string}\n"
    string=$(printf "      [ %s ] Small or Large Profile Install Resources" "${PROFILE_RES}")
    printf "${string}\n"
    startEndSection "Prerequisite Checker Tool Summary"
}

function startEndSection() {
    section=$1
    log $INFO "=================================${section}================================="
}

function main {
    echo
    log $INFO "Starting IBM Cloud Pak for AIOps prerequisite checker v4.2..."
    echo
    initialize
    verifyOC
    evaluateGlobalVariables

    fail_found=0
    echo
    checkOCPVersion || fail_found=1
    checkEntitlementSecret || fail_found=1
    checkStorage || fail_found=1
    checkSmallOrLargeProfileInstall || fail_found=1

    showSummary

    return $fail_found
}

main || exit 1
