#!/bin/bash

# Install or Uninstall IBM Infrastructure Automation V0.0.1

set -o pipefail

# last execution
CALLER=$_
timestamp=`date +%Y%m%d%H%M%S`
logs="ibm-ia-logs."
logpath="/tmp/$logs$timestamp.txt"

helpFunc() {
       echo "Usage $0"
       echo "Use this script to install or uninstall IBM Infrastructure Automation"
       echo
       echo "  REQUIRED FLAGS:"
       echo 
       echo "     --mode                           The mode the script should use. The available args are:"
       echo
       echo "                                          install"
       echo "                                          uninstall"
       echo "                                          modify"
       echo
       echo "     --acceptLicense                  Providing this flag constitutes acceptance of the IBM Infrastructure Automation license"
       echo "                                      found at http://ibm.biz/cp4waiops-311-license. No argument is required"
       echo
       echo "     --namespace                      The namespace that you are installing IBM Infrastructure Automation to"
       echo 
       echo "     --pullSecret                     The name of the pull secret to be used with IBM Infrastructure Automation; this pull secret"
       echo "                                      must be created in the namespace provided with the --namespace flag"
       echo
       echo "     --rwxStorageClass                The name of the storageclass to be used with components requiring RWX accessMode"
       echo "     --rwoStorageClass                The name of the storageclass to be used with components requiring RWO accessMode; if blank"
       echo "                                      will use the storageClass provided with the --rwxStorageClass flag"
       echo
       echo "   OPTIONAL FLAGS:"
       echo
       echo "     --crName                         The name of the installations.orchestrator.management.ibm.com. Defaults to infra-auto-instance"
       echo "                                      Required flag in conjunction with --mode uninstall."
       echo 
       echo "     --kubeconfigPath                 The absolute path to the kubeconfig file to access the cluster; provide this option if you"
       echo "                                      are not currently logged into the target cluster with oc. E.g.:"
       echo "                                      $0 --kubeconfigPath /path/to/kubeconfig \\"
       echo "                                      --mode install \\"
       echo "                                      --acceptLicense \\"
       echo "                                      --namespace infra-auto \\"
       echo "                                      --pullSecret ibm-management-pull-secret \\"
       echo "                                      --rwxStorageClass file-storage-sc \\"
       echo "                                      --rwoStorageClass block-storage-sc"
       echo
       echo "     --roks                           Provide this flag when installing IBM Infrastructure Automation on ROKS (Red Hat Openshift Kubernetes Service)"
       echo "                                      Must provide the --roksRegion and --roksZone flags as well. The --roks flag does not require an argument"
       echo
       echo "     --roksRegion                     The ROKS region of the cluster"
       echo
       echo "     --roksZone                       The ROKS zone of the cluster"
       echo
       echo "                                      Example of ROKS usage:"
       echo "                                      $0 --mode install \\"
       echo "                                      --acceptLicense \\"
       echo "                                      --namespace infra-auto \\"
       echo "                                      --pullSecret ibm-management-pull-secret \\"
       echo "                                      --rwxStorageClass ibmc-file-gold \\"
       echo "                                      --rwoStorageClass ibmc-block-gold \\"
       echo "                                      --roks \\"
       echo "                                      --roksZone us-south \\"
       echo "                                      --roksRegion dal10"
       echo
       echo "  MODES AND USAGE:"
       echo
       echo "     install                          Description: Automatically Install IBM Infrastructure Automation and its dependencies"
       echo "                                      Usage: $0 --mode install \\"
       echo "                                      --acceptLicense \\"
       echo "                                      --namespace infram-auto \\"
       echo "                                      --pullSecret ibm-management-pull-secret \\"
       echo "                                      --rwxStorageClass file-storage-sc \\"
       echo "                                      --rwoStorageClass block-storage-sc"
       echo
       echo "     uninstall                        Description: Uninstall IBM Infrastructure Automation"
       echo "                                      Usage: $0 --mode uninstall --namespace infra-auto --crName infra-auto-instance"
       echo
       echo "     modify                           Description: Modify an existing IBM Infrastructure Automation installation to remove unused components"
       echo "                                      Usage: $0 --mode modify --acceptLicense"
       echo
       exit 0
}

parse_args() {
    ARGC=$#
    if [ $ARGC -eq 0 ] ; then
	helpFunc
        exit
    fi
    while [ $ARGC -ne 0 ] ; do
	if [ "$1" == "-n" ] || [ "$1" == "-N" ] ; then
	    ARG="-N"
	else
	    PRE_FORMAT_ARG=$1
	    ARG=`echo $1 | tr .[a-z]. .[A-Z].`
	fi
	case $ARG in
	    "--KUBECONFIGPATH")	#
		pathToKubeconfig=$2; shift 2; ARGC=$(($ARGC-2)) ;;
	    "--MODE")
		mode=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--NAMESPACE")
		installNamespace=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--CRNAME")
		crName=$2; shift 2; ARGC=$(($ARGC-2)); ;;	    
	    "--PULLSECRET")
		installPullSecret=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--RWXSTORAGECLASS")
		rwxStorageClass=$2; shift 2; ARGC=$(($ARGC-2)); ;;
 	    "--RWOSTORAGECLASS")
		rwoStorageClass=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--ACCEPTLICENSE")
		acceptLicense="true"; shift 1; ARGC=$(($ARGC-1)); ;;
	    "--ROKS")
		roksMode="true"; shift 1; ARGC=$(($ARGC-1)); ;;	    
	    "--ROKSREGION")
		roksRegion=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--ROKSZONE")
		roksZone=$2; shift 2; ARGC=$(($ARGC-2)); ;;
	    "--HELP")	#
		helpFunc
		exit 1 ;;
	    *)
		echo "Argument \"${PRE_FORMAT_ARG}\" not known. Exiting." | tee -a "$logpath"
		echo "" | tee -a "$logpath"
		helpFunc
		exit 1 ;;
	esac
    done
}

checkOptions() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Checking Flags and Arguments" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    echo "Parameters provided:" >> "$logpath"
    echo "" >> "$logpath"
    echo "pathToKubeconfig: $pathToKubeconfig" >> "$logpath"
    echo "mode: $mode" >> "$logpath"
    echo "installNamespace: $installNamespace" >> "$logpath"
    echo "nstallPullSecret: $installPullSecret" >> "$logpath"
    echo "rwxStorageClass: $rwxStorageClass" >> "$logpath"
    echo "rwoStorageClass: $rwoStorageClass" >> "$logpath"
    echo "acceptLicense: $acceptLicense" >> "$logpath"
    echo "roksMode: $roksMode" >> "$logpath"    
    echo "roksRegion: $roksRegion" >> "$logpath"
    echo "roksZone: $roksZone" >> "$logpath"
    echo "crName: $crName" >> "$logpath"
    echo ""
    if [[ -z "${crName}" ]]; then
	crName="infra-auto-instance"
	echo "crName was not provided, using default" >> "$logpath"
    fi
    if [[ "${mode}" == "install" ]]; then
	echo "Mode: install" | tee -a "$logpath"
	if [[ "${acceptLicense}" != "true" ]]; then
	    echo "ERROR: You must accept the license to install the product by providing the --acceptLicense flag. The license text is available at http://ibm.biz/cp4waiops-311-license" | tee -a "$logpath"
	    echo "E.g.: $0 --mode install --acceptLicense --namespace infra-auto --pullSecret ibm-management-pull-secret --rwxStorageClass file-storage-sc --rwoStorageClass block-storage-sc" | tee -a "$logpath"
	    exit 1
	fi

	if [[ -z "${installNamespace}" || -z "${installPullSecret}" || -z "${rwxStorageClass}" ]]; then
	    echo "ERROR: One or more flags or arguments was not provided. Please provide the necessary flags and arguments for the install mode:" | tee -a "$logpath"
	    echo "E.g.: $0 --mode install --acceptLicense --namespace infra-auto --pullSecret ibm-management-pull-secret --rwxStorageClass file-storage-sc --rwoStorageClass block-storage-sc" | tee -a "$logpath"
	    exit 1
	fi
	if [[ "${roksMode}" == "true" ]]; then
	    if [[ -z "${roksRegion}" || -z "${roksZone}" ]]; then
		echo "One or more flags or arguments was not provided for installing on ROKS. Please provide the necessary flags and arguments for the install mode:" | tee -a "$logpath"
		echo "                                      $0 --mode install \\"
		echo "                                      --acceptLicense \\"
		echo "                                      --namespace infra-auto \\"
		echo "                                      --pullSecret ibm-management-pull-secret \\"
		echo "                                      --rwxStorageClass ibmc-file-gold \\"
		echo "                                      --rwoStorageClass ibmc-block-gold \\"
		echo "                                      --roks \\"
		echo "                                      --roksZone us-south \\"
		echo "                                      --roksRegion dal10"
		exit 1
	    fi
	fi
    elif [[ "${mode}" == "uninstall" ]]; then
	echo "Mode: uninstall" | tee -a "$logpath"
	if [[ -z "${installNamespace}" ]]; then
	    echo "ERROR: The namespace where the IBM Infrastructure Automation CR was created was not provided. Please provide it with the --namespace flag" | tee -a "$logpath"
	    echo "E.g.: $0 --mode uninstall --namespace infra-auto" | tee -a "$logpath"
	    exit 1
	fi
    elif [[ "${mode}" == "modify" ]]; then
	if [[ "${acceptLicense}" != "true" ]]; then
	    echo "ERROR: You must accept the license to modify the product by providing the --acceptLicense flag" | tee -a "$logpath"
	    echo "E.g.: $0 --mode modify --acceptLicense" | tee -a "$logpath"
	    exit 1
	fi
    else
	echo "ERROR: Mode unrecognized: $mode" | tee -a "$logpath"
	echo "Available modes are:"
	echo
	echo "install"
	echo "E.g.: $0 --mode install --acceptLicense --namespace infra-auto --pullSecret ibm-management-pull-secret --rwxStorageClass file-storage-sc --rwoStorageClass block-storage-sc" 
	echo
	echo "uninstall"
	echo "E.g.: $0 --mode uninstall --namespace infra-auto"
	
	exit 1
    fi
    return 0
}

checkIfocInstalled() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "oc binary check" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"    
    which oc > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "ERROR: The oc binary could not be found in the PATH; ensure that the local of this binary is in the PATH" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	echo "Current PATH: $PATH" | tee -a "$logpath"
	exit 1
    else
	echo "Found the oc binary" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi
}

checkLogin() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Attempting to access cluster" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    oc get pods -A | grep "openshift" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "Not currently logged into a cluster with oc; attempting to use kubeconfig file"
	if [[ "${pathToKubeconfig}" == "" || -z "${pathToKubeconfig}" ]]; then
	    echo "ERROR: Not currently logged into a cluster with oc and no path was provided to the --kubeconfigPath flag, please log into the cluster or provide a path to kubeconfig with flag"
	    exit 1
	elif [[ ! -f "${pathToKubeconfig}" ]]; then
	    echo "ERROR: Not currently logged into a cluster with oc and no file was found at ${pathToKubeconfig}; please log into the cluster or use an absolute path to the kubeconfig for the cluster with the --pathToKubeconfig flag" | tee -a "$logpath"
	    exit 1
	fi
	oc get pods -A --kubeconfig="${pathToKubeconfig}" | grep "openshift" > /dev/null 2>&1
	result=$?
	if [[ "${result}" -ne 0 ]]; then
	    echo "ERROR: Attempt to access cluster with kubeconfig at ${pathToKubeconfig} has failed" | tee -a "$logpath"
	    exit 1
	fi
	"kubeconfig provided allows access to cluster; using this cluster" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi
    echo "Currently logged into cluster; using this cluster" | tee -a "$logpath" # TODO output name and add sleep to give them a chance to ctrl+c cancel
    echo "" | tee -a "$logpath"
    return 0
}

checkOCPversion() {
	echo "**********************************************************************" | tee -a "$logpath"
	echo "Checking OCP version" | tee -a "$logpath"
	echo "**********************************************************************" | tee -a "$logpath"
	echo "" | tee -a "$logpath"	
	local clusterVersion=`oc get clusterversion | grep "version" | awk '{ print $2 }'`
	local major=`echo $clusterVersion | awk -F"[.]" '{ print $1}'`
	local minor=`echo $clusterVersion | awk -F"[.]" '{ print $2}'`
	if [[ "${major}" == "4" ]]; then
		if [[ "${minor}" == "6" || "${minor}" == "8" ]]; then
			echo "Version is compatible" | tee -a "$logpath"
			echo "" | tee -a "$logpath"
			return 0
		fi
	fi
	echo "ERROR: OCP version $clusterVersion is not a supported release for IBM Infrastructure Automation; the only supported releases are OCP 4.6 or OCP 4.8" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	exit 1
}

checkNamespace() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Verifying installation namespace exists" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"    
    oc get namespace $installNamespace > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then

	echo "ERROR: The namespace $installNamespace does not exist. Please create it and then create the pull secret named $installPullSecret inside of it" | tee -a "$logpath"
	exit 1

    fi
    echo "Namespace validation successful" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

checkPullSecret() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Verifying pull secret exists" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"    
    oc get secret $installPullSecret -n $installNamespace > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "ERROR: Could not find $installPullSecret in $installNamespace; please ensure that the name of the pull secret is correct and exists in $installNamespace" | tee -a "$logpath"
	exit 1
    fi
    
    echo "Validation of pull secret successful" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

checkStorageClass() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Checking StorageClass" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"    
    oc get storageclass $rwxStorageClass > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "ERROR: The $rwxStorageClass does not exist. Please provide a valid RWX storageclass via the --rwxStorageClass flag" | tee -a "$logpath"
	exit 1
    fi

    if [[ -z "${rwoStorageClass}" ]]; then
	echo "No explicit rwoStorageClass was provided; using rwxStorageClass instead" | tee -a "$logpath"
	rwoStorageClass=$rwxStorageClass
    fi
    
    echo "Validation of storageclass successful" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

checkIfPreviousInstallExists() {
    # TODO include checks for the rest of IA
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Ensuring cluster is free of previous install" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    oc get crd | grep "installations.orchestrator.management.ibm.com"
    local result=$?
    if [[ "${result}" -eq 0 ]]; then
	oc get installations.orchestrator.management.ibm.com -A | grep "${crName}" > /dev/null 2>&1
	result1=$?
	oc get installations.orchestrator.management.ibm.com -A | grep "infra-auto-instance" > /dev/null 2>&1
	result2=$?
	if [[ "${result1}" -eq 0 || "${result2}" -eq 0 ]]; then
	    echo "ERROR: There is an existing instance of Infrastructure Automation; if you wish to re-install IBM Infrastructure Automation, please uninstall the one that is currently installed first. To see the location of the installation execute 'oc get installations.orchestrator.management.ibm.com -A"
	    echo "E.g.: $0 --mode uninstall --namespace infra-auto --crName infra-auto-instance"
	    exit 1
	fi
    fi
    
    echo "Validation of absence of Infrastructure Automation installation successful" | tee -a "$logpath"
    echo ""
    return 0
}

createCScatalogSourceAndSubscription() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Creating Common Services CatalogSource and Subscription" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: opencloud-operators
  namespace: openshift-marketplace
spec:
  displayName: IBMCS Operators
  publisher: IBM
  sourceType: grpc
  image: docker.io/ibmcom/ibm-common-service-catalog:3.12
  updateStrategy:
    registryPoll:
      interval: 45m
EOF

cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-common-service-operator
  namespace: openshift-operators
spec:
  channel: v3
  installPlanApproval: Automatic
  name: ibm-common-service-operator
  source: opencloud-operators
  sourceNamespace: openshift-marketplace
EOF

oc get CommonService common-service -n ibm-common-services > /dev/null 2>&1
local result=$?
local counter=0
while [[ "${result}" -ne 0 ]]
do
    if [[ $counter -gt 36 ]]; then
	echo "ERROR: The CommonService CustomResource was not created within three minutes. This is an unrecoverable error. Please attempt to run the script again in mode: uninstall then again in mode: install." | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	exit 1
    fi
    counter=$((counter + 1))
    echo "The CommonService CustomResource has not been created yet; delaying modification" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    sleep 5s
    oc get CommonService common-service -n ibm-common-services > /dev/null 2>&1
    result=$?
done

echo "The CommonService CustomResource has been created; modifying it to reduce resource usage" | tee -a "$logpath"
echo "" | tee -a "$logpath"

cat << EOF | oc apply -f -
apiVersion: operator.ibm.com/v3
kind: CommonService
metadata:
  name: common-service
  namespace: ibm-common-services
spec:
  size: small
EOF
}

createIAcatalogSourceAndSubscription() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Creating Infrastructure Automation Catalog Source and Subscription" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-marketplace
spec:
  displayName: Infrastructure Automation Installer Catalog
  publisher: IBM Infrastructure Automation
  sourceType: grpc
  image: quay.io/cp4mcm/cp4mcm-orchestrator-catalog:2.3.20
  updateStrategy:
    registryPoll:
      interval: 45m
EOF


    cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ibm-management-orchestrator
  namespace: openshift-operators
spec:
  channel: 2.3-stable
  installPlanApproval: Automatic
  name: ibm-management-orchestrator
  source: ibm-management-orchestrator
  sourceNamespace: openshift-marketplace
EOF
return 0
}

coolOff() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Initializing Services; Check back in 10 minutes" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    # Waiting for Common Services to cool off before creating the OperandRequest
    sleep 600s
    return 0
}

# TODO update url in this function
checkOrchestrator() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Checking Orchestrator" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        

    local counter=0
    while [[ true ]]; do
	oc rollout status deployment ibm-management-orchestrator -n openshift-operators > /dev/null 2>&1
	local result=$?
	if [[ "${result}" -eq 0 ]]; then
	    break
	elif [[ "${counter}" -ge 45 ]]; then
	    echo "ERROR: The ibm-management-orchestrator deployment has not completed its rollout. See the Knowledge Center troubleshooting topic: https://www.ibm.com/docs/en/cloud-paks/cp-management/2.3.x?topic=troubleshooting" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    exit 1
	fi
	echo -n " ... " | tee -a "$logpath"
	counter=$((counter + 1))
	sleep 60s
    done

    echo "" | tee -a "$logpath"
    echo "The ibm-management-orchestrator deployment has successfully rolled out" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

# Create installation CR
createInstallationCR() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Creating installations.orchestrator.management.ibm.com CR" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
cat << EOF | oc apply -f -
apiVersion: orchestrator.management.ibm.com/v1alpha1
kind: Installation
metadata:
  name: ${crName}
  namespace: ${installNamespace}
spec:
  imagePullSecret: ${installPullSecret}
  license:
    accept: true
  mcmCoreDisabled: true
  pakModules:
  - config:
    - enabled: true
      name: ibm-management-im-install
    - enabled: false
      name: ibm-management-infra-grc
    - enabled: true
      name: ibm-management-infra-vm
    - enabled: true
      name: ibm-management-cam-install
      spec:
        manageservice:
          camLogsPV:
            name: cam-logs-pv
            persistence:
              accessMode: ReadWriteMany
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 100Gi
              storageClassName: ${rwxStorageClass}
              useDynamicProvisioning: true
          camMongoPV:
            name: cam-mongo-pv
            persistence:
              accessMode: ReadWriteOnce
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 150Gi
              storageClassName: ${rwoStorageClass}
              useDynamicProvisioning: true
          camTerraformPV:
            name: cam-terraform-pv
            persistence:
              accessMode: ReadWriteMany
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 150Gi
              storageClassName: ${rwxStorageClass}
              useDynamicProvisioning: true
    - enabled: true
      name: ibm-management-service-library
    enabled: true
    name: infrastructureManagement
  - config:
    - enabled: true
      name: ibm-management-monitoring
      spec:
        monitoringDeploy:
          global:
            environmentSize: size0
            persistence:
              storageClassOption:
                cassandrabak: none
                cassandradata: ibmc-block-gold
                couchdbdata: ibmc-block-gold
                datalayerjobs: ibmc-block-gold
                elasticdata: ibmc-block-gold
                kafkadata: ibmc-block-gold
                zookeeperdata: ibmc-block-gold
              storageSize:
                cassandrabak: 500Gi
                cassandradata: 500Gi
                couchdbdata: 50Gi
                datalayerjobs: 50Gi
                elasticdata: 50Gi
                kafkadata: 100Gi
                zookeeperdata: 10Gi
        operandRequest: {}
    enabled: false
    name: monitoring
  - config:
    - enabled: true
      name: ibm-management-notary
    - enabled: true
      name: ibm-management-image-security-enforcement
    - enabled: true
      name: ibm-management-mutation-advisor
    - enabled: true
      name: ibm-management-vulnerability-advisor
    enabled: false
    name: securityServices
  - config:
    - enabled: true
      name: ibm-management-sre-chatops
    enabled: false
    name: operations
  - config:
    - enabled: true
      name: ibm-management-manage-runtime
    enabled: false
    name: techPreview
  storageClass: ${rwxStorageClass}
EOF

result=$?
if [[ "${result}" -ne 0 ]]; then
    echo "ERROR: Could not create installations.orchestrator.management.ibm.com CR" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    exit 1
fi

echo "Successfully Created CR"
return 0
}

createInstallationCRroks() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Creating installations.orchestrator.management.ibm.com CR in ROKS mode" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
cat << EOF | oc apply -f -
apiVersion: orchestrator.management.ibm.com/v1alpha1
kind: Installation
metadata:
  name: ${crName}
  namespace: ${installNamespace}
spec:
  imagePullSecret: ${installPullSecret}
  license:
    accept: true
  mcmCoreDisabled: true
  pakModules:
  - config:
    - enabled: true
      name: ibm-management-im-install
    - enabled: false
      name: ibm-management-infra-grc
    - enabled: true
      name: ibm-management-infra-vm
    - enabled: true
      name: ibm-management-cam-install
      spec:
        manageservice:
          camLogsPV:
            name: cam-logs-pv
            persistence:
              accessMode: ReadWriteMany
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 100Gi
              storageClassName: ${rwxStorageClass}
              useDynamicProvisioning: true
          camMongoPV:
            name: cam-mongo-pv
            persistence:
              accessMode: ReadWriteOnce
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 150Gi
              storageClassName: ${rwoStorageClass}
              useDynamicProvisioning: true
          camTerraformPV:
            name: cam-terraform-pv
            persistence:
              accessMode: ReadWriteMany
              enabled: true
              existingClaimName: ""
              existingDynamicVolume: false
              size: 150Gi
              storageClassName: ${rwxStorageClass}
              useDynamicProvisioning: true
          roks: true
          roksRegion: ${roksRegion}
          roksZone: ${roksZone}
    - enabled: true
      name: ibm-management-service-library
    enabled: true
    name: infrastructureManagement
  - config:
    - enabled: true
      name: ibm-management-monitoring
      spec:
        monitoringDeploy:
          global:
            environmentSize: size0
            persistence:
              storageClassOption:
                cassandrabak: none
                cassandradata: ibmc-block-gold
                couchdbdata: ibmc-block-gold
                datalayerjobs: ibmc-block-gold
                elasticdata: ibmc-block-gold
                kafkadata: ibmc-block-gold
                zookeeperdata: ibmc-block-gold
              storageSize:
                cassandrabak: 500Gi
                cassandradata: 500Gi
                couchdbdata: 50Gi
                datalayerjobs: 50Gi
                elasticdata: 50Gi
                kafkadata: 100Gi
                zookeeperdata: 10Gi
        operandRequest: {}
    enabled: false
    name: monitoring
  - config:
    - enabled: true
      name: ibm-management-notary
    - enabled: true
      name: ibm-management-image-security-enforcement
    - enabled: true
      name: ibm-management-mutation-advisor
    - enabled: true
      name: ibm-management-vulnerability-advisor
    enabled: false
    name: securityServices
  - config:
    - enabled: true
      name: ibm-management-sre-chatops
    enabled: false
    name: operations
  - config:
    - enabled: true
      name: ibm-management-manage-runtime
    enabled: false
    name: techPreview
  storageClass: ${rwxStorageClass}
EOF

result=$?
if [[ "${result}" -ne 0 ]]; then
    echo "ERROR: Could not create installations.orchestrator.management.ibm.com CR in ROKS mode" | tee -a "$logpath"
    echo ""
    exit 1
fi

echo "Successfully created CR in ROKS Mode"
return 0
}

# I think this will remain in Updating since we have mcm-core disabled an no RHACM installed
verifyInstallationStatus() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Verifying Installation Status" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    for ((retry=0;retry<=60;retry++)); do
	INSTALL_STATUS=$(oc -n ${installNamespace} get installation.orchestrator.management.ibm.com ${crName} -o jsonpath="{.status.phase}")

	if [[ ${INSTALL_STATUS} == "Failed" ]]; then
	    echo "ERROR: The IBM Infrastructure Automation CR has met an unrecoverable error" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    oc logs -n openshift-operators $(oc -n openshift-operators get pod -l name=ibm-management-orchestrator -o jsonpath="{.items[0].metadata.name}") | tail -n 300 | tee -a "$logpath"
	    exit 1
	fi

	if [[ ${INSTALL_STATUS} == "Running" ]]; then
	    echo "Installer job has completed." | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    return 0
	fi

	echo " ... " | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	sleep 60
    done

    echo "ERROR: The IBM Infrastructure Automation CR has failed to come ready within one hour" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    oc logs -n openshift-operators $(oc -n openshift-operators get pod -l name=ibm-management-orchestrator -o jsonpath="{.items[0].metadata.name}") | tail -n 300 | tee -a "$logpath"
    exit 1
}

verifyCAMstatus() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Checking CAM" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        

    # check mongodb
    local counter=0
    while [[ true ]]; do
	oc rollout status deployment cam-mongo -n management-infrastructure-management > /dev/null 2>&1
	local result=$?
	if [[ "${result}" -eq 0 ]]; then
	    break
	elif [[ "${counter}" -ge 45 ]]; then
	    echo "ERROR: The cam-mongo deployment has not completed its rollout." | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    exit 1
	fi
	echo -n " ... " | tee -a "$logpath"
	counter=$((counter + 1))
	sleep 60s
    done

    echo "" | tee -a "$logpath"
    echo "The cam-mongo deployment has successfully rolled out" | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    # check cam-bpd-cds

    counter=0
    while [[ true ]]; do
	oc rollout status deployment cam-bpd-cds -n management-infrastructure-management > /dev/null 2>&1
	result=$?
	if [[ "${result}" -eq 0 ]]; then
	    break
	elif [[ "${counter}" -ge 45 ]]; then
	    echo "ERROR: The cam-bpd-cds deployment has not completed its rollout." | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    exit 1
	fi
	echo -n " ... " | tee -a "$logpath"
	counter=$((counter + 1))
	sleep 60s
    done

    echo "" | tee -a "$logpath"
    echo "The cam-bpd-cds deployment has successfully rolled out" | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    return 0
}

trimDownUI() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Removing disabled UI elements" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    parent_idlist=" observe applications costs govern-risk monitor sre"
    idlist=" overview clusters hybrid-applications content-runtimes chargeback license-advisor grc ma va monitor incidents infra-monitoring synthetics monitoring sre-incidents sre-bastion sre-sessionmgmt metering administer-monitoring administer-tunnel administer-tunnel-audit ${parent_idlist}"

    for id in ${idlist}; do
	ids=($(oc get navconfigurations.foundation.ibm.com multicluster-hub-nav -n kube-system -o jsonpath='{.spec.navItems[*].id}'))
	i=0
	while [ $i -lt ${#ids[@]} ]; do
	    if [[ "${ids[i]}" == "${id}" ]]; then
		oc patch navconfigurations.foundation.ibm.com multicluster-hub-nav -n kube-system --type='json' -p '[{"op": "remove", "path": "/spec/navItems/'$i'"}]'
		echo "Found ${id} of id ${i}. Deleting it with return code $?." >> "$logpath"
		break
	    fi
	    let i=i+1
	done
    done
    echo "Successfully removed disabled UI Elements" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
}

manipulateFoundation() {
    local count=$1
    echo "**********************************************************************" | tee -a "$logpath"
    if [[ "${count}" -eq 0 ]]; then
	echo "Removing disabled Foundation elements" | tee -a "$logpath"
    elif [[ "${count}" -eq 1 ]]; then
	echo "Scaling up Foundation elements for subsequent removal" | tee -a "$logpath"
    fi
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    local deployList="example-complianceapi-api-deploy example-complianceapi-monitor-deploy example-grcrisk gateway-kong ibm-kong-operator ibm-license-advisor-instance ibm-license-advisor-operator ibm-license-advisor-sender-instance ibm-license-advisor-sender-operator ibm-management-awspolicy-ansible ibm-management-hybridgrc-car  ibm-management-hybridgrc-core ibm-management-mcm-operator ibm-management-vmpolicy-ansible ibm-secure-tunnel-operator ibm-sre-bastion-operator ibm-sre-inventory-operator multicluster-hub-findingsapi multicluster-hub-grafeas multicluster-hub-grc-policy multicluster-hub-legato multicluster-hub-policy-adapter sre-inventory-inventory-aggregator sre-inventory-inventory-api sre-inventory-inventory-cfcollector sre-inventory-inventory-rhacmcollector sre-tunnel-controller sre-tunnel-tunnel-network-api sre-tunnel-tunnel-ui-mcmtunnelui example-complianceapi-monitor-deploy sre-bastion-sre-ui-mcmsreui sre-bastion-teleport-auth sre-bastion-teleport-proxy sre-bastion-bastion-backend-deploy"
    local statefulsetList="hybridgrc-postgresql sre-inventory-inventory-redisgraph sre-bastion-vault sre-bastion-postgresql"
    local replicaCount=$count
    local ns="kube-system"
    for deployItem in ${deployList}; do
	oc -n ${ns} scale deploy ${deployItem} --replicas=${replicaCount}
    done
    for statefulsetItem in ${statefulsetList}; do
	oc -n ${ns} scale statefulset ${statefulsetItem} --replicas=${replicaCount}
    done
    oc -n ${ns} delete job sre-inventory-inventory-redis-secret-job
    echo "Completed scaling of deployments, statefulsets, and jobs" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

waitUntilDeleted() {
    local resourceType=$1
    local namespace=$2
    local resourceName=$3
    local waitTime=$4

    if [[ "${resourceType}" == "" ]]; then
	echo "The resourceType argument was null" >> $logpath
	return 1
    fi

    if [[ "${namespace}" == "" ]]; then
	echo "The namespace argument was null" >> $logpath
	return 1
    fi
    
    if [[ "${resourceName}" == "" ]]; then
	echo "The resourceName argument was null" >> $logpath
	return 0
    fi

    if ! [[ "${waitTime//[0-9]}" = "" ]]; then
	
	echo "The waitTime argument was not equal to a non-negative integer" >> $logpath
	return 1
    fi

    local stillThere=0
    local counter=0
    while [[ "${stillThere}" -eq 0 && "${counter}" -le $waitTime ]] # 
    do
	sleep 5s
	oc get "${resourceType}" -n "${namespace}" | grep "${resourceName}" > /dev/null 2>&1
	local result=$?
	if [[ "${result}" -ne 0 ]]; then
	    stillThere=1
	    echo "Successfully deleted:" | tee -a "$logpath"
	    echo "resourceType: $resourceType" | tee -a "$logpath"
	    echo "resourceName: $resourceName" | tee -a "$logpath"
	    echo "namespace: $namespace" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	    return 0
	else
	    ((counter=counter+5))
	    echo "Waiting for resource to be deleted:" | tee -a "$logpath"
	    echo "resourceType: $resourceType" | tee -a "$logpath"
	    echo "resourceName: $resourceName" | tee -a "$logpath"
	    echo "namespace: $namespace" | tee -a "$logpath"
	    echo "Seconds to timeout: $counter/$waitTime" | tee -a "$logpath"
	    echo "" | tee -a "$logpath"
	fi
    done

    if [[ "${result}" -eq 0 ]]; then
	echo "Failed to delete ${resourceType} ${resourceName} in namespace ${namespace}" | tee -a "$logpath"
	echo "Please contact your kubernetes administrator to manually delete this resource" | tee -a "$logpath"
	sleep 3s
	return 1
    fi
}

# deleteResource takes five args
# 1 resourceType, e.g. namespace, configmap, secret, etc.
# 2 namespace, i.e. the namespace that the resource exists in; the function does not support deleting resources that are not namespace bound
# 3 resourceName, i.e. the name of the resource
# 4 removeFinalizers, either "true" or "false", if set to true, it will remove the finalizers for the resource before attempting to delete it
# 5 waitTime, the number of SECONDS to wait in total to see if the resource was successfully deleted, MUST be an integer

# It issue a delete with --force and --grace-period=0, check to see if removeFinalizers is set to true, and if it is which, it will issue a delete, with --force and --grace-period=0
# It then checks to see if the resource remains for five minutes
# If the resource does not exist it will return with 0

deleteResource() {
    local resourceType=$1
    local namespace=$2
    local resourceName=$3
    local removeFinalizers=$4
    local waitTime=$5

    if [[ "${resourceName}" == "" ]]; then
	echo "The resourceName argument was null" >> $logpath
	return 0
    fi

    if [[ "${namespace}" == "" ]]; then
	echo "The namespace argument was null" >> $logpath
	return 1
    fi

    if [[ "${resourceType}" == "" ]]; then
	echo "The resourceType argument was null" >> $logpath
	return 1
    fi

    if [[ "${removeFinalizers}" == "" ]]; then
	echo "The removeFinalizers argument was null" >> $logpath
	return 1
    elif [[ "${removeFinalizers}" != "true" && "${removeFinalizers}" != "false" ]]; then
	echo "The removeFinalizers argument was not set to 'true' and was not set to 'false'" >> $logpath
	return 1
    fi

    if ! [[ "${waitTime//[0-9]}" = "" ]]; then
	echo "The waitTime argument was not equal to a non-negative integer" >> $logpath
	return 1
    fi

    oc get "${resourceType}" "${resourceName}" -n "${namespace}" > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "${resourceType}: ${resourceName} in namespace: ${namespace} does not exist; skipping deletion attempt" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi

    echo "Deleting ${resourceType}: ${resourceName} in namespace: ${namespace}" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    
    oc delete "${resourceType}" "${resourceName}" -n "${namespace}" --force --grace-period=0 & >> "$logpath"

    echo "" | tee -a "$logpath"

    sleep 3s

    oc get "${resourceType}" "${resourceName}" -n "${namespace}" > /dev/null 2>&1
    result=$?
    if [[ "${removeFinalizers}" = "true" ]]; then
      if [[ "${result}" -ne 1 ]]; then
        echo "Resource still exists; attempting to remove finalizers from resource" | tee -a "$logpath"
        echo "" | tee -a "$logpath"
        patchString='{"metadata":{"finalizers": []}}'
        oc patch "${resourceType}" "${resourceName}" -n "${namespace}" -p "$patchString" --type=merge >> "$logpath"
        result=$?
        if [[ "${result}" -ne 0 ]]; then
            return 1
        fi
      fi
    fi

    echo "Waiting for resource to be deleted" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    waitUntilDeleted "${resourceType}" "${namespace}" "${resourceName}" "${waitTime}"
    result=$?
    if [[ "${result}" -ne 0 ]]; then
	return 1
    fi
    return 0
}


deleteKind() {
    local kind=$1

    if [[ "${kind}" == "" ]]; then
	echo "The kind argument was null" >> $logpath
	return 1
    fi

    echo "Deleting all resources of kind: $kind" | tee -a "$logpath"
    echo "" | tee -a "$logpath"

    
    local crs=`oc get ${kind} --all-namespaces=true | sed -n '1!p'`
    if [[ "${crs}" == "" ]]; then
	echo "No resources of kind: $kind found" >> "$logpath"
	return 0
    fi

    local result=0

    for crNsLine in "$crs"; do
	if [[ "$crNsLine" != "" ]]; then
            local cr=`echo "$crNsLine" | awk '{ print $2 }'`
            local ns=`echo "$crNsLine" | awk '{ print $1 }'`
	    deleteResource "${kind}" "${ns}" "${cr}" "false" 300
	    local result=$(( result + $? ))
	fi
    done
    return $result
}

removeImInstall() {
    local ns="management-infrastructure-management"
    echo "Attempting to delete all resources associated with ibm-management-im-install" | tee -a "$logpath"
    deleteKind "IMInstall"
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-im-install resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-im-install" | tee -a "$logpath"
	return 0
    fi
}

removeInfraVM() {
    local ns="management-infrastructure-management"
    echo "Attempting to delete all resources associated with ibm-management-infra-vm" | tee -a "$logpath"

    deleteKind "Connection"
    local result=$?
    deleteKind "TagLabelMap"
    result=$(( result + $? ))
    deleteKind "VirtualMachineDiscover"
    result=$(( result + $? ))
    deleteKind "VirtualMachine"
    result=$(( result + $? ))
    
    if [[ "${result}" -ne 0 ]]; then
	echo "$result ibm-management-infra-vm resources may remain" | tee -a "$logpath"
	return $result
    else
	echo "Successfully deleted all resources associated with ibm-management-infra-vm" | tee -a "$logpath"
	return 0
    fi
}

validate(){
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Validating flags, parameters, and environment integrity" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    checkOptions
    checkIfocInstalled
    checkLogin
    if [[ "${mode}" == "install" ]]; then
	checkOCPversion
	checkNamespace
    	checkPullSecret
    	checkStorageClass	    
    	checkIfPreviousInstallExists
    fi
    echo "" | tee -a "$logpath"
    echo "Validation of flags, parameters, and environment complete" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    return 0
}

installFunc() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Installing IBM Infrastructure Automation" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    echo "Checking if Common Service is already installed."
    oc -n openshift-operators get subscriptions | grep ibm-common-service-operator > /dev/null 2>&1
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
        echo "Creating Common Service Catalog Source."
        createCScatalogSourceAndSubscription
    else
        echo "Skip creating Common Service Catalog Source as it exists"
    fi
    createIAcatalogSourceAndSubscription
    coolOff
    checkOrchestrator
    if [[ "$roksMode" == "true" ]]; then
	createInstallationCRroks
    else
	createInstallationCR
    fi
#    verifyInstallationStatus
    verifyCAMstatus
    trimDownUI
    manipulateFoundation 0
    echo "Installation of IBM Infrastructure Automation complete" | tee -a "$logpath"
    exit 0
}

deleteSecrets() {
    echo "Deleting secrets left after uninstall" | tee -a "$logpath"
    declare -a secret_array=(
	"compliance-api-ca-cert-secrets"
	"grc-risk-ca-cert-secrets"
	"hybridgrc-postgresql-secrets"
	"ibm-license-advisor-token"
	"ibm-licensing-bindinfo-ibm-licensing-upload-token"
	"ibm-licensing-token"
	"ibm-management-pull-secret"
	"icp-metering-receiver-proxy-secret"	
	"license-advisor-db-config"
	"multicluster-hub-cluster-api-provider-apiserver-ca-cert-sdk"
	"multicluster-hub-console-uiapi-secrets"
	"multicluster-hub-core-apiserver-secrets"
	"multicluster-hub-core-klusterlet-secrets"
	"multicluster-hub-core-webhook-secrets"
	"multicluster-hub-etcd-secrets"
	"multicluster-hub-findingsapi-certificates-credentials"
	"multicluster-hub-findingsapi-proxy-secret"
	"multicluster-hub-grafeas-certificates-credentials"
	"multicluster-hub-grafeas-secret"
	"multicluster-hub-grc-secrets"
	"multicluster-hub-legato-certificates-credentials"
	"multicluster-hub-topology-secrets"
	"sa-iam-secrets"
	"search-redisgraph-secrets"
	"search-redisgraph-user-secrets"
	"search-search-api-secrets"
	"search-search-secrets"
	"search-tiller-client-certs"
	"sh.helm.release.v1.gateway.v1"
	"sh.helm.release.v1.multicluster-hub.v1"
	"sh.helm.release.v1.sre-bastion.v1"
	"sh.helm.release.v1.sre-inventory.v1"
	"sre-bastion-bastion-secret"
	"sre-bastion-postgresql"
	"sre-inventory-aggregator-secrets"
	"sre-inventory-inventory-rhacm-redisgraph-secrets"
	"sre-inventory-inventory-rhacm-redisgraph-user-secrets"
	"sre-inventory-redisgraph-secrets"
	"sre-inventory-redisgraph-user-secrets"
	"sre-inventory-search-api-secrets"
	"sre-postgresql-bastion-secret"
	"sre-postgresql-vault-secret"
	"sre-vault-config"
	"teleport-credential"
	"vault-credential"
    )

    local result=0
    
    for element in ${secret_array[@]}
    do
	deleteResource "secret" "kube-system" "${element}" "false" 300
	result=$(( result + $? ))
    done

    deleteResource "secret" "${JOB_NAMESPACE}" "ibm-management-pull-secret" "false" 3600
    
    if [[ "${result}" -ne 0 ]]; then
	echo "Not all IBM Infrastructure Automation secrets in the kube-system namespace could be successfully deleted." | tee -a "$logpath"
	echo "Number of secrets that may remain: $result" | tee -a "$logpath"
    else
	echo "Successfully deleted all IBM Infrastructure Automation secrets in the kube-system namespace" | tee -a "$logpath"
    fi
    return $result
}

removeMisc() {
    echo "Removing miscellaneous resources"
    deleteResource "pvc" "kube-system" "data-sre-bastion-postgresql-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "etcd-data-multicluster-hub-etcd-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "data-sre-inventory-inventory-redisgraph-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "hybridgrc-db-pvc-hybridgrc-postgresql-0" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "license-advisor-pvc" "false" 300
    result=$(( result + $? ))
    deleteResource "pvc" "kube-system" "sre-bastion-teleport-storage-pvc" "false" 300
    result=$(( result + $? ))
    orchestratorInstallPlan=`oc get InstallPlan -n openshift-operators | grep "ibm-management-orchestrator" | awk '{ print $1 }'`
    deleteResource "InstallPlan" "openshift-operators" "${orchestratorInstallPlan}" "false" 300
    result=$(( result + $? ))
    hybridappInstallPlan=`oc get InstallPlan -n openshift-operators | grep "ibm-management-hybridapp" | awk '{ print $1 }'`
    deleteResource "InstallPlan" "openshift-operators" "${hybridappInstallPlan}" "false" 300
    result=$(( result + $? ))
    if [[ "${result}" -eq 0 ]]; then
	echo "All remaining miscellaneous resources related to IBM Infrastructure Automation have been removed" | tee -a "$logpath"
	return 1
    else
	echo "$result operators, CSVs, or subscriptions related to IBM Infrastructure Automation may remain" | tee -a "$logpath"
	return 0
    fi
}

deleteRoute(){
    echo "Deleting vault-route in kube-system namespace"
    vaultRoute=`oc get route -n kube-system | grep "vault-route"`
    deleteResource "route" "kube-system" "${vaultRoute}" "false" 300
    result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "Could not delete vault-route route in kube-system namespace" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 1
    else
	echo "Successfully deleted vault-route route in kube-system namespace" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	return 0
    fi
}

uninstallFunc() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Uninstalling IBM Infrastructure Automation" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    removeImInstall
    removeInfraVM
    echo "Scaling pods back up so that OperandRequest for Foundation can successfully be deleted; please return in ten minutes" | tee -a "$logpath"
    manipulateFoundation 1
    sleep 600s
    deleteResource "installation.orchestrator.management.ibm.com" "${installNamespace}" "${crName}" "false" 3600
    local result=$?
    if [[ "${result}" -ne 0 ]]; then
	echo "ERROR: Could not delete the installation instance within the time allotted; aborting uninstall; please attempt to delete the workspace again"
	exit 1
    fi
    # We must make absolutely certain that there are no installation CRs installed; like in the instance that the
    # customer passed the wrong name of the CR; in that case, the CR will remain, but the subscription, CatalogSource
    # and everything else will be deleted, leaving the cluster in a bad state
    installs=`oc get installation.orchestrator.management.ibm.com -A`
    if [[ -z "${installs}" ]]; then
	echo "No other installations found. Proceeding." | tee -a "$logpath"
    else
	echo "Other IBM Infrastructure Infrastructure installation.orchestrator.management.ibm.com CRs were found other than the one specified when the script was ran with the --crName flag; please re-execute the script with the name of the remaining CR. To see the remaining CR, execute 'oc get installation.orchestrator.management.ibm.com -A'" | tee -a "$logpath"
	echo "" | tee -a "$logpath"
	exit 1
    fi
    deleteResource "subscriptions.operators.coreos.com" "openshift-operators" "ibm-management-orchestrator" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.2" "false" 300    
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.3" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.4" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.5" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.6" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.7" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.8" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.9" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.10" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.11" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.12" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.13" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.14" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.15" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.16" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.17" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.18" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.19" "false" 300
    result=$(( result + $? ))
    deleteResource "csv" "openshift-operators" "ibm-management-orchestrator.v2.3.20" "false" 300
    result=$(( result + $? ))
    deleteResource "catalogsource" "openshift-marketplace" "ibm-management-orchestrator" "false" 300
    result=$(( result + $? ))
    deleteResource "deployment" "openshift-operators" "ibm-management-orchestrator" "false" 300
    result=$(( result + $? ))
    deleteResource "secret" "management-infrastructure-management" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "openshift-operators" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    deleteResource "secret" "kube-system" "ibm-management-pull-secret" "true" 300
    result=$(( result + $? ))
    removeMisc
    result=$(( result + $? ))
    deleteRoute
    result=$(( result + $? ))
    deleteSecrets
    result=$(( result + $? ))
    #deleteCRDs
    #result=$(( result + $? ))
    # oc delete OperandRequest -n ibm-common-services --force common-service ibm-commonui-request ibm-iam-request ibm-mongodb-request management-ingress monitoring-grafana-operator-request platform-api-request
    # deleteResource "OperandRequest" "ibm-common-services" "common-service" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "ibm-commonui-request" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "ibm-iam-request" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "ibm-mongodb-request" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "management-ingress" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "monitoring-grafana-operator-request" "false" 300
    # result=$(( result + $? ))
    # deleteResource "OperandRequest" "ibm-common-services" "platform-api-request" "false" 300
    # result=$(( result + $? ))
    # meteringInstallPlan=`oc get InstallPlan -n ibm-common-services | grep "ibm-metering-operator" | awk '{ print $1 }'`
    # deleteResource "InstallPlan" "ibm-common-services" "${meteringInstallPlan}" "false" 300
    # result=$(( result + $? ))
    # mongodbInstallPlan=`oc get InstallPlan -n ibm-common-services | grep "ibm-mongodb" | awk '{ print $1 }'`
    # deleteResource "InstallPlan" "ibm-common-services" "${mongodbInstallPlan}" "false" 300
    # result=$(( result + $? ))
    if [[ "${result}" -ne 0 ]]; then
	echo "ERROR: Could not complete removal of secrets, routes, pvcs, and OperandRequests" | tee -a "$logpath"
	exit 1
    fi
    echo "Uninstallation of IBM Infrastructure Automation complete" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
}

modifyFunc() {
    echo "**********************************************************************" | tee -a "$logpath"
    echo "Modifying IBM Infrastructure Automation" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"        
    echo "Modification of IBM Infrastructure Automation complete"    
    trimDownUI
    manipulateFoundation 0
    echo "Modification of IBM Infrastructure Automation complete" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
}

main() {
    echo "**********************************************************************" | tee -a "$logpath"    
    echo "Executing $0; logs available at $logpath" | tee -a "$logpath"
    echo "**********************************************************************" | tee -a "$logpath"
    echo "" | tee -a "$logpath"
    validate
    case "${mode}" in
	"install")
	    installFunc; exit $? ;;
	"uninstall")
	    uninstallFunc; exit $? ;;
	"modify")
	    modifyFunc; exit $? ;;
	*)
	    echo "ERROR: Validation should have prevented getting this far! Error!" | tee -a "$logpath"
	    exit 1 ;;
    esac
}

parse_args "$@"

main
