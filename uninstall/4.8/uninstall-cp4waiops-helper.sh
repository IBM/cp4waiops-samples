#!/bin/bash
#
# © Copyright IBM Corp. 2020, 2024
# SPDX-License-Identifier: Apache2.0
#
. ./uninstall-cp4waiops.props

export OPERATORS_PROJECT=openshift-operators

# SLEEP TIMES
SLEEP_SHORT_LOOP=5
SLEEP_MEDIUM_LOOP=15
SLEEP_LONG_LOOP=30
SLEEP_EXTRA_LONG_LOOP=40

# Tracing prefixes
INFO="[INFO]"
WARNING="[WARNING]"
ERROR="[ERROR]"

log () {
   local log_tracing_prefix=$1
   local log_message=$2
   local log_options=$3
    
   if [[ ! -z $log_options ]]; then
      echo -e $log_options "$log_tracing_prefix $log_message"
   else
      echo -e "$log_tracing_prefix $log_message" 
   fi
}

display_help() {
   echo "**************************************** Usage ********************************************"
   echo ""
   echo " This script is used to uninstall IBM Cloud Pak for AIOps version 4.8"
   echo " The following prereqs are required before you run this script: "
   echo " - oc CLI is installed and you have logged into the cluster using oc login"
   echo " - Update uninstall-cp4waiops.props with components that you want to uninstall"
   echo ""
   echo " Usage:"
   echo " ./uninstall-cp4waiops.sh -h -s"
   echo "  -h Prints out the help message"
   echo "  -s Skip asking for confirmations"   
   echo ""
   echo "*******************************************************************************************"
}

check_namespaced_install () {
    log $INFO "Checking where operators are installed..."
    operator_name=$(oc get subscription.operators.coreos.com/ibm-aiops-orchestrator -n $OPERATORS_PROJECT -o name --ignore-not-found)
    if [[ ! -z "$operator_name" ]]; then
        # Operator is installed in all-ns mode
        AIOPS_NAMESPACED="false"
        log $INFO "\033[1;36mUninstalling AIOps and its components from the cluster scope.\033[0m"
        return 0
    fi

    # Check that the operator is in the ns the user provided
    operator_name=$(oc get subscription.operators.coreos.com/ibm-aiops-orchestrator -n $CP4WAIOPS_PROJECT -o name --ignore-not-found)
    if [[ ! -z "$operator_name" ]]; then
        # Operator is in the user provided ns, this is a namespaced install
        AIOPS_NAMESPACED="true"
        log $INFO "\033[1;36mUninstalling AIOps from the namespace $CP4WAIOPS_PROJECT. \033[0m"
        return 0
    fi

}

check_namespaced_bedrock () {
    log $INFO "Finding if IBM Cloud Pak Foundational Services is Namespaced or Global"

    # Check the CSV through all NS and grep for "Foundational Services"
    CSV=$(oc get csv -A | grep "foundational services")

    # Use awk to obtain important info
    NAMESPACE=$(echo $CSV | awk '{print $1}')
    NAME=$(echo $CSV | awk '{print $2}')

    # If operator is found in openshift-operators, cpfs is global (false)
    if [[ "${NAMESPACE}" == "openshift-operators" ]]; then
        log $INFO "IBM Cloud Pak Foundational Services: Global Scope"
        return 1
    else
        log $INFO "IBM Cloud Pak Foundational Services: Namespaced Scope"
        return 0
    fi
}

check_oc_resource_exists () {
  local resource=$1
  local resource_name=$2
  local namespace=$3

  if oc get $resource $resource_name -n $namespace  > /dev/null 2>&1; then
     resource_exists="true"
  else
     resource_exists="false"
  fi

  echo "$resource_exists"
}

finalResourceCheckODLM () {
    # Check for operandrequest, operandconfig, and operandregistries
    opreq=$(oc get operandrequest -n $CP4WAIOPS_PROJECT --ignore-not-found=true > /dev/null 2>&1)
    if [[ "${opreq}" == "0" ]]; then
        log $INFO "OperandRequests still remain"
        oc get operandrequests -n $CP4WAIOPS_PROJECT
    fi

    opcg=$(oc get operandconfig -n $CP4WAIOPS_PROJECT --ignore-not-found > /dev/null 2>&1)
    if [[ "${opcg}" == "0" ]]; then
        log $INFO "OperandConfig still remain"
        oc get operandconfig -n $CP4WAIOPS_PROJECT
    fi

    opreg=$(oc get operandregistries -n $CP4WAIOPS_PROJECT --ignore-not-found=true > /dev/null 2>&1)
    if [[ "${opreg}" == "0" ]]; then
        log $INFO "Operandregistries still remain"
        oc get operandregistries -n $CP4WAIOPS_PROJECT > /dev/null 2>&1
    fi

    if [[ "${opreq}" == "0" && "${opcg}" == "0" && "${opreg}" == "0" ]]; then
        log $ERROR "Some ODLM resources remain. Please remove them manually."
        return 1
    else
        return 0
    fi
}

finalBedrockResourceCheck () {
    BR_FLAG="false"

    for CRD in ${BEDROCK_CRDS[@]}; do
        echo $CRD > /dev/tty
        check=$(oc get $CRD -n $CP4WAIOPS_PROJECT --ignore-not-found=true --no-headers=true > /dev/tty)
        if [[ "${check}" != *"the server doesn't have a resource "* || "${check}" != *"No resources found"* ]]; then
            BR_FLAG="true"
            oc get $CRD -n $CP4WAIOPS_PROJECT
            echo "check: $check"
            echo "here" > /dev/tty
        else
            echo "it's deleted" > /dev/tty
        fi
        echo > /dev/tty
    done


    echo "Going to return code here" > /dev/tty
    if [[ "${BR_FLAG}" == "true" ]]; then
        return 1
    else
        return 0
    fi
}

unsubscribe () {
    local operator_name=$1	
    local dest_namespace=$2
    local operator_label=$3

    if [[ ( -z "$operator_name" ) && ( ! -z  "$operator_label" ) ]]; then
       operator_name=$(oc get subscription.operators.coreos.com -n $dest_namespace -l $operator_label -o name)
       if [[ ! -z "$operator_name" ]]; then
          operator_exists="true"
       else
          operator_exists="false"
       fi
    elif [[ ( ! -z "$operator_name" ) ]]; then
        operator_exists=$(check_oc_resource_exists "subscription.operators.coreos.com" $operator_name $dest_namespace)
    else
       log $ERROR "operator_name and operator_label are empty, please provide one of them and try again"
       exit 1
    fi
    
    if [[ "$operator_exists" == "true" ]]; then
            
       if [[ "$operator_name" != "subscription.operators.coreos.com"*  ]]; then
          operator_name="subscription.operators.coreos.com/"$operator_name
       fi
        
        # Get CluserServiceVersion
        CSV=$(oc get $operator_name -n $dest_namespace --ignore-not-found --output=jsonpath={.status.installedCSV})
        
        # Delete Subscription
        log $INFO "Deleting the subscription $operator_name"
        oc delete $operator_name -n $dest_namespace

        # Delete the Installed ClusterServiceVersion
        if [[ ! -z "$CSV"  ]]; then

            log $INFO "Deleting the clusterserviceversion $CSV"
            oc delete clusterserviceversion $CSV -n $dest_namespace

            log $INFO "Waiting for the deletion of all the ClusterServiceVersions $CSV for the subscription of the operator $operator_name"	
            # Wait for the Copied ClusterServiceVersions to cleanup
            if [ -n "$CSV" ] ; then
                LOOP_COUNT=0
                while [ `oc get clusterserviceversions --all-namespaces --field-selector=metadata.name=$CSV --ignore-not-found | wc -l` -gt 0 ]
                do
                        sleep $SLEEP_LONG_LOOP
                        LOOP_COUNT=`expr $LOOP_COUNT + 1`
                        if [ $LOOP_COUNT -gt 10 ] ; then
                                log $ERROR "There was an error in deleting the ClusterServiceVersions $CSV for the subscription of the operator $operator_name "
                                break
                        fi
                done
            fi
            log $INFO "Deletion of all the ClusterServiceVersions $CSV for the subscription of the operator $operator_name completed successfully."
        else
            log $WARNING "The ClusterServiceVersion for the operator $operator_name does not exist, skipping the deletion of the ClusterServiceVersion for operator $operator_name"
        fi

    else
        log $WARNING "The subscription for the operator $operator_name with label $operator_label does not exist in $dest_namespace, skipping unsubscription."
    fi
}

# If any custom instances created by users for below CRD's
# "eventmanagergateways.ai-manager.watson-aiops.ibm.com": None of the instance is expected to be present with install
# "kongs.management.ibm.com" : Expected custom resource to be ignored named 'gateway' that gets created with install.
aiops_custom_instance_exists () {
  
  local namespace=$1
  
  custom_instance_exists=false
  if [ `oc get kongs.management.ibm.com -n $namespace --ignore-not-found --no-headers -o name | grep -v "gateway" | wc -l` -gt 0 ] ||
     [ `oc get eventmanagergateways.ai-manager.watson-aiops.ibm.com -n $namespace --ignore-not-found --no-headers -o name | wc -l` -gt 0 ]; then
     custom_instance_exists=true
  fi
}

aiops_operands_exists () {

  local namespace=$1
  
  operand_exists=false
  if [ `oc get operandrequests ibm-aiops-ai-manager -n $namespace --ignore-not-found --no-headers | wc -l` -gt 0 ] ||
                [ `oc get operandrequests ibm-aiops-aiops-foundation -n $namespace --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
                [ `oc get operandrequests ibm-aiops-application-manager  -n $namespace --ignore-not-found --no-headers |  wc -l` -gt 0 ]  ||
                [ `oc get operandrequests aiopsedge-base -n $namespace --ignore-not-found --no-headers | wc -l` -gt 0 ] ||
                [ `oc get operandrequests aiopsedge-cs -n $namespace --ignore-not-found --no-headers | wc -l` -gt 0 ] ; then
     operand_exists=true
  fi
  echo $operand_exists

}

delete_installation_instance () {
    local installation_name=$1
    local project=$2

    if  [ `oc get installations.orchestrator.aiops.ibm.com $installation_name -n $project --ignore-not-found | wc -l` -gt 0 ] ; then
        log $INFO "Found installation CR $installation_name to delete."
        log $INFO "Waiting for $resource instances to be deleted.  This will take a while...."

        oc delete installations.orchestrator.aiops.ibm.com $installation_name -n $project --ignore-not-found;
    
        LOOP_COUNT=0
        while [ `oc get installations.orchestrator.aiops.ibm.com $installation_name -n $project --ignore-not-found | wc -l` -gt 0 ]
        do
        sleep $SLEEP_EXTRA_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 20 ] ; then
            log $ERROR "Timed out waiting for installation instance $installation_name to be deleted"
            exit 1
        else
            log $INFO "Waiting for installation instance to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "$installation_name instance got deleted successfully!"

    else
        log $INFO "The $installation_name installation instance is not found, skipping the deletion of $installation_name."
    fi

    check_additional_installation_exists
    # if return code of check_additional_installation_exists is 1... change the value of $project to newly found namespace
    if [[ "$?" == "1" ]]; then
        project=$CP4WAIOPS_PROJECT
    fi

    log $INFO "Checking if operandrequests are all deleted "        
    LOOP_COUNT=0
    while [ $(aiops_operands_exists $project) == "true" ]
    do
	      sleep $SLEEP_LONG_LOOP
	      LOOP_COUNT=`expr $LOOP_COUNT + 1`
	      if [ $LOOP_COUNT -gt 20 ] ; then
	          log $WARNING "Timed out waiting for operandrequests to be deleted automatically"
	
	          log $INFO "Below operand requests are left behind in namespace $project"
	          oc get operandrequests -n $project -o name
	          log $INFO "Trying to delete remaining operandrequests manually, only for AIOps"
	          oc delete operandrequests ibm-aiops-ai-manager -n $project --ignore-not-found
	          oc delete operandrequests ibm-aiops-aiops-foundation -n $project --ignore-not-found
	          oc delete operandrequests ibm-aiops-application-manager -n $project --ignore-not-found
	          oc delete operandrequests aiopsedge-base -n $project --ignore-not-found
	          oc delete operandrequests aiopsedge-cs -n $project --ignore-not-found    
	          while [ $(aiops_operands_exists $project) == "true" ]
	          do
	            sleep $SLEEP_LONG_LOOP
	            LOOP_COUNT=`expr $LOOP_COUNT + 1`
	            if [ $LOOP_COUNT -gt 30 ] ; then
	               log $ERROR "Timed out waiting for operandrequests to be deleted after trying manual deletion"
	               log $ERROR "Below operand requests are left behind in namespace $project"
	               oc get operandrequests -n $project -o name
	               exit 1
	            fi
	          done
	      else
	          log $INFO "Found following operandrequests in the project: "
	          log $INFO "$(oc get operandrequests -n $project --no-headers)"
	          log $INFO "Waiting for operandrequests instances to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
	      fi
    done
    log $INFO "Expected operandrequests got deleted successfully!"
    oc patch -n $CP4WAIOPS_PROJECT rolebinding/admin -p '{"metadata": {"finalizers":null}}' 2>>/dev/null

}

delete_project () {
    local project=$1

    if  [ `oc get project $project --ignore-not-found | wc -l` -gt 0 ] ; then
        log $INFO "Found project $project to delete."

        oc delete ns $project --ignore-not-found;

        log $INFO "Waiting for $project to be deleted...."
        LOOP_COUNT=0
        while [ `oc get project $project --ignore-not-found | wc -l` -gt 0 ]
        do
            sleep $SLEEP_EXTRA_LONG_LOOP
            LOOP_COUNT=`expr $LOOP_COUNT + 1`
            if [ $LOOP_COUNT -gt 20 ] ; then
                log $ERROR "Timed out waiting for project $project to be deleted"
                exit 1
            else
                log $INFO "Waiting for project $project to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
            fi
        done

        log $INFO "Project $project got deleted successfully!"
    else
        log $INFO "Project $project is not found, skipping the deletion of $project."
    fi
}

deleteCertManagerResources () {
    log $INFO "Deleting Certmanager Resources"
    oc delete issuer.cert-manager.io cs-ss-issuer -n $CP4WAIOPS_PROJECT --ignore-not-found=true
    oc delete issuer.cert-manager.io cs-ca-issuer -n $CP4WAIOPS_PROJECT --ignore-not-found=true
}

deleteIAM_Workaround () {
    log $INFO "Delete MISC IAM ConfigMap and Role/Rolebinding"
    oc delete configmap cs-keycloak-theme -n $CP4WAIOPS_PROJECT

    log $INFO "Delete role and rolebinding"
    oc delete rolebinding leader-election-rolebinding -n $CP4WAIOPS_PROJECT
    oc delete role leader-election-role -n $CP4WAIOPS_PROJECT
}

# Check if Infrastructure Automation is installed by looking for the CSV
iaEnabled() {
    iaEnabled=$(oc get csv -n $CP4WAIOPS_PROJECT | grep ibm-infrastructure-automation-operator)
    if [[ "$iaEnabled" == ""  ]]; then
        # Infrastructure Automation is not installed
        return 1 # Non-zero exit code (false)
    else
        # Infrastructure Automation is installed
        return 0 # Zero exit code (success, true)
    fi
}

delete_bedrock () {
    echo
    log $INFO "Starting uninstall of IBM Cloud Pak Foundational Services components"

    # Only delete IBM Common Services resources if IA is not installed with AIOps
    if ! iaEnabled; then
        # Since ZenService is automatically deleted via odlm and some resources linger due to their controller being
        # prematurely uplifted, we need to patch the finalizers for zenextension and zenclient.
        log $INFO "Delete ZenService related resources"
        delete_zenservice 

        # log $info "Delete CommonService kind"
        oc delete commonservices --all -n $CP4WAIOPS_PROJECT --ignore-not-found=true

        # Uninstall cpfs operator
        log $info "Uninstall CPFS"
        unsubscribe "" $CP4WAIOPS_PROJECT "operators.coreos.com/ibm-common-service-operator.$CP4WAIOPS_PROJECT"

        # Delete all operandrequests in install namespace
        # Note :  Verify there are no operandrequests & operandbindinfo at this point before proceeding.  It may take a few minutes for them to go away.
        log $INFO "Checking if operandrequests are all deleted "
        LOOP_COUNT=0
        while [ `oc get operandrequests -n $CP4WAIOPS_PROJECT --ignore-not-found --no-headers | wc -l ` -gt 0 ]
        do
        sleep $SLEEP_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 30 ]; then
            log $ERROR "Timed out waiting for all operandrequests to be deleted.  Cannot proceed with uninstallation til all operandrequests in ibm-common-services project are deleted."
            exit 1
        elif [ "$LOOP_COUNT" == "15" ]; then
            # oc delete --all operandrequests -n ibm-common-services
            oc delete --all operandrequests -n $CP4WAIOPS_PROJECT       
        else
            log $INFO "Found following operandrequests in the project: $(oc get operandrequests -n $CP4WAIOPS_PROJECT --ignore-not-found --no-headers)"
            log $INFO "Waiting for operandrequests instances to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "Expected operandrequests got deleted successfully!"

        # Delete all operandconfigs
        log $info "Check for operandconfigs to delete"
        oc delete operandconfigs --all -n $CP4WAIOPS_PROJECT --ignore-not-found

        # Delete all operandregistries
        log $info "Check for operandregistries"
        oc delete operandregistries --all -n $CP4WAIOPS_PROJECT --ignore-not-found

        finalResourceCheckODLM
        if [[ "$?" == "0" ]]; then
            log $info "Uninstall ODLM"
            unsubscribe "operand-deployment-lifecycle-manager-app" $CP4WAIOPS_PROJECT ""
        else
            log $ERROR Please delete all ODLM resources in $CP4WAIOPS_PROJECT namespace, then restart the script.
            exit 1
        fi

        oc delete deployment meta-api-deploy -n $CP4WAIOPS_PROJECT --ignore-not-found
        oc delete service meta-api-svc -n $CP4WAIOPS_PROJECT --ignore-not-found

        oc delete MutatingWebhookConfiguration ibm-common-service-webhook-configuration -n $CP4WAIOPS_PROJECT --ignore-not-found

        deleteMiscBedrockResources       

        # We need to wait a bit before we can perform a check. Perhaps we can keep running this function a finite amount of times before timing out the
        # script
        resourceCheckCounter=1

        log $INFO "Checking for Bedrock resources"
        while [[ "${resourceCheckCounter}" -le "5" ]]; do
            # At each iteration start with a fresh BR_FLAG variable set to false
             BR_FLAG="false"

            # If attempts reach 5, go ahead and end the script
            if [[ "${resourceCheckCounter}" -eq "5" ]]; then
                log $ERROR "Some Bedrock resources remain. Please delete them, then restart the script."
                exit 1
            fi

            #  Poll for each CRs for each CRD. If found, set the BR_FLAG to true
            log $INFO "Resource Check Attempt: $resourceCheckCounter"
            for CR in ${BEDROCK_CRDS[@]}; do
                echo $CR
                check="$(oc get $CR -n $CP4WAIOPS_PROJECT)"
                if [[ -n "${check}" ]]; then
                    BR_FLAG="true"
                    oc get $CR -n $CP4WAIOPS_PROJECT
                    echo
                else
                    echo "None Found"
                    echo
                fi
            done
            echo

            # After all crds have been searched for, if the BR_FLAG is still false -- we know all CRDs are safe to delete. We can
            # break out of the while-loop now.
            if [[ "${BR_FLAG}" == "false" ]]; then
                break
            fi

            # Otherwise, resources are still left over. If that's the case, let's try this entire thing after 30 seconds
            echo "Resources found... Trying again in 30 seconds."
            resourceCheckCounter=$((resourceCheckCounter + 1))
            sleep 30
        done

        # TODO: Remove this as soon as Bedrock addresses these resources
        deleteIAM_Workaround

        log $INFO "Deleting CPFS leases in $CP4WAIOPS_PROJECT"
        for LEASE in ${BEDROCK_LEASES[@]}; do
            log $INFO "Deleting lease $LEASE.."
            oc delete $LEASE -n $CP4WAIOPS_PROJECT --ignore-not-found
        done

        log $INFO "Deleting CPFS configmaps in $CP4WAIOPS_PROJECT"
        for CONFIGMAP in ${BEDROCK_CONFIGMAPS[@]}; do
            log $INFO "Deleting configmap $CONFIGMAP.."
            oc delete $CONFIGMAP -n $CP4WAIOPS_PROJECT --ignore-not-found
        done

        log $INFO "Deleting CPFS PVCs in $CP4WAIOPS_PROJECT"
        for PVC in ${BEDROCK_PVCS_LABELS[@]}; do
            log $INFO "Deleting PVC $PVC.."
            oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
        done

        log $INFO "Deleting Namespaced Bedrock Secrets"
        for s in ${BEDROCK_SECRETS[@]}; do
            oc delete secret $s -n $CP4WAIOPS_PROJECT --ignore-not-found
        done

        deleteCertManagerResources
    fi
}

delete_crd_group () {
    local crd_group=$1

    case "$crd_group" in
    "CP4AIOPS_CRDS") 
        for CRD in ${CP4AIOPS_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "CP4AIOPS_DEPENDENT_CRDS") 
        for CRD in ${CP4AIOPS_DEPENDENT_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "BEDROCK_CRDS") 
        for CRD in ${BEDROCK_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "ASM_CRDS")
        for CRD in ${ASM_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    esac
}

analyze_script_properties(){

if [[ $DELETE_ALL == "true" ]]; then
   DELETE_PVCS="true"
   DELETE_CRDS="true"
fi

if [[ $DELETE_ALL != "true" ]] && [[ $DELETE_ALL != "false" ]]; then
    log $ERROR "The DELETE_ALL flag must have a value of either \"true\" or \"false\". Please review the uninstall-cp4waiops.props file."
    exit 1
fi

if [[ $DELETE_PVCS != "true" ]] && [[ $DELETE_PVCS != "false" ]]; then
    log $ERROR "The DELETE_PVCS flag must have a value of either \"true\" or \"false\". Please review the uninstall-cp4waiops.props file."
    exit 1
fi

if [[ $DELETE_CRDS != "true" ]] && [[ $DELETE_CRDS != "false" ]]; then
    log $ERROR "The DELETE_CRDS flag must have a value of either \"true\" or \"false\". Please review the uninstall-cp4waiops.props file."
    exit 1
fi

}

display_script_properties(){

log $INFO "##### Properties in uninstall-cp4waiops.props #####"
log $INFO
if [[ $DELETE_ALL == "true" ]]; then
	log $INFO "\033[1;36m The script uninstall-cp4waiops.props has 'DELETE_ALL=true', hence the script will execute wih below values: \033[0m"
else
    log $INFO "The script uninstall-cp4waiops.props has the properties with below values: "
fi
log $INFO
log $INFO "CP4WAIOPS_PROJECT=$CP4WAIOPS_PROJECT"
log $INFO "INSTALLATION_NAME=$INSTALLATION_NAME"
log $INFO "DELETE_PVCS=\033[1;36m$DELETE_PVCS\033[0m"
log $INFO "DELETE_CRDS=\033[1;36m$DELETE_CRDS\033[0m"
log $INFO
log $INFO "##### Properties in uninstall-cp4waiops.props #####"
}

check_additional_installation_exists(){
  log $INFO "Checking if any additional installation resources found in the cluster."
  installation_returned_value=$(oc get installations.orchestrator.aiops.ibm.com -A)
  if [[ ! -z $installation_returned_value  ]] ; then
     log $ERROR "Remaining installation cr found : "
     oc get installations.orchestrator.aiops.ibm.com -A
     log $INFO "Deleting remaining installation"
     
     # Get name and namespace of additional install
     local INSTALLATION_NAME=$(oc get installations.orchestrator.aiops.ibm.com -A --no-headers=true | awk '{print $2}')
     local CP4WAIOPS_PROJECT=$(oc get installations.orchestrator.aiops.ibm.com -A --no-headers=true | awk '{print $1}')
     # Change the value of the name and namespace in the props file
     sed -i -e "s,^CP4WAIOPS_PROJECT=\".*\",CP4WAIOPS_PROJECT=\"$CP4WAIOPS_PROJECT\",;  s,^INSTALLATION_NAME=\".*\",INSTALLATION_NAME=\"$INSTALLATION_NAME\"," ./uninstall-cp4waiops.props
     . ./uninstall-cp4waiops.props

     oc delete installation.orchestrator.aiops.ibm.com $INSTALLATION_NAME -n $CP4WAIOPS_PROJECT
     return 1
  else
     log $INFO "No additional installation resources found in the cluster."
     return 0
  fi
}

check_additional_asm_exists() {
    log $INFO "Checking if any additional ASM resources are on the cluster."
    if [ $(oc get asms.asm.ibm.com -A --no-headers | wc -l) -gt 0 ] || [ $(oc get asmformations.asm.ibm.com -A --no-headers | wc -l) -gt 0 ]; then
        log $INFO "ASM resource instances were found in the cluster."
        DELETE_ASM="false"
    else
    log $INFO "No ASM resource instances were found outside the $CP4WAIOPS_PROJECT namespace, so the ASM CRDs can be deleted."
    DELETE_ASM="true"
    fi
}

delete_connections() {
   until GET_AIOC_MSG=$(oc -n $CP4WAIOPS_PROJECT get connectorconfigurations.connectors.aiops.ibm.com -o name 2>&1); do
        if [[ "$GET_AIOC_MSG" == "error: the server doesn't have a resource type \"connectorconfigurations\"" ]]; then
            log $INFO "ConnectorConfiguration CRD is not installed, no need to clean up connections"
            return
        fi
        sleep 10
   done
   log $INFO "Deleting all ConnectorConfigurations"
   oc -n $CP4WAIOPS_PROJECT delete connectorconfigurations.connectors.aiops.ibm.com --all &
   log $INFO "waiting for ConnectorComponent termination"
   until [[ `oc -n $CP4WAIOPS_PROJECT get connectorcomponents.connectors.aiops.ibm.com -o name | wc -l` -eq 0 ]]; do
        oc -n $CP4WAIOPS_PROJECT get connectorcomponents.connectors.aiops.ibm.com -o name | while read r; do
            DEL_TIMESTAMP=$(oc -n $CP4WAIOPS_PROJECT get $r -o jsonpath={.metadata.deletionTimestamp} 2>>/dev/null) || continue
            DEL_TIMESTAMP=$(date --date $DEL_TIMESTAMP +%s 2>>/dev/null) || continue
            NOW=$(date +%s)
            DELTA=$((NOW - DEL_TIMESTAMP))
            if ((DELTA > 300)); then
                log $INFO "removing finalizers from ConnectorComponent that has been Terminating for over $DELTA seconds"
                oc -n $CP4WAIOPS_PROJECT patch $r -p '{"metadata":{"finalizers":[]}}' --type=merge
            fi
        done
        sleep 10
   done
   log $INFO "Finished deleting ConnectorConfigurations"
}

delete_securetunnel(){
    log $INFO "Deleting the Secure tunnel resources in $CP4WAIOPS_PROJECT "
    oc -n $CP4WAIOPS_PROJECT delete tunnelconnections.securetunnel.management.ibm.com --all 2>>/dev/null
    oc -n $CP4WAIOPS_PROJECT delete applicationmappings.securetunnel.management.ibm.com --all 2>>/dev/null
    oc -n $CP4WAIOPS_PROJECT delete templates.securetunnel.management.ibm.com --all 2>>/dev/null
    oc -n $CP4WAIOPS_PROJECT delete tunnelconnections.tunnel.management.ibm.com --all 2>>/dev/null
    oc -n $CP4WAIOPS_PROJECT delete applicationmappings.tunnel.management.ibm.com --all 2>>/dev/null
    oc -n $CP4WAIOPS_PROJECT delete templates.tunnel.management.ibm.com --all 2>>/dev/null
    # check if there have another Secure tunnel operator reference to the Secure Tunnel CRDs
    COUNT=`oc get deployment -A | grep ibm-secure-tunnel-operator | wc -l`
    if [ "${COUNT}" == "0" ]; then
        log $INFO "No other Secure tunnel operator reference to the Secure tunnel CRDs, deleting them "
        oc delete crd tunnelconnections.securetunnel.management.ibm.com 2>>/dev/null
        oc delete crd applicationmappings.securetunnel.management.ibm.com 2>>/dev/null
        oc delete crd templates.securetunnel.management.ibm.com 2>>/dev/null
        oc delete crd tunnelconnections.tunnel.management.ibm.com 2>>/dev/null
        oc delete crd applicationmappings.tunnel.management.ibm.com 2>>/dev/null
        oc delete crd templates.tunnel.management.ibm.com 2>>/dev/null
    fi
    log $INFO "Finished deleting securetunnel resources"
    # Securetunnel secrets are removed via resource group CP4AIOPS_INTERNAL_SECRETS
}

delete_zenservice() {
    # Check for client. if exist, then patch finalizer and delete
    log $INFO "Checking for ZenClient"
    oc get client.oidc.security.ibm.com -n $CP4WAIOPS_PROJECT zenclient-$CP4WAIOPS_PROJECT
    if [[ "$?" == "0" ]]; then
        log $INFO "Deleting ZenClient found"
        oc patch -n $CP4WAIOPS_PROJECT client.oidc.security.ibm.com zenclient-$CP4WAIOPS_PROJECT  --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
        oc delete client.oidc.security.ibm.com -n $CP4WAIOPS_PROJECT zenclient-$CP4WAIOPS_PROJECT
    fi

    log $INFO "Delete zen setup-job"
    oc delete job setup-job -n $CP4WAIOPS_PROJECT --ignore-not-found=true

    log $info "Delete Zen Service Account"
    oc delete serviceaccount ibm-zen-operator-serviceaccount  -n $CP4WAIOPS_PROJECT --ignore-not-found=true

    # These are typically deleted by Zen, but these are added in the event an install fails. When an install fails, Zen fails to cleanup properly.
    ZenSecrets=("ibm-zen-objectstore-cert" "zen-metastore-edb-replica-client" "zen-metastore-edb-server" "zen-secrets-aes-key" "zen-service-broker-secret" "ibm-zen-file-store-encryption-key" "default-ssl" "admin-user-details" "internal-tls" "internal-tls-pkcs8" "meta-api-broker-secret" "meta-jwt" "meta-tls" "meta-api-broker-secret" "ibm-zen-metastore-edb-secret" "ibm-nginx-internal-tls-ca") 
    log $INFO "Delete Zen secrets"
    for s in ${ZenSecrets[@]}; do
        oc delete secret $s -n $CP4WAIOPS_PROJECT --ignore-not-found=true
    done

    # Same deal as above with ZenSecrets
    if [[ $DELETE_PVCS == "true" ]]; then
        oc delete pvc -l app.kubernetes.io/component=zen-minio -n $CP4WAIOPS_PROJECT --ignore-not-found=true
    fi
}

# Delete cert manager resources found only in cp4aiops namespace
delete_cert_manager_resources () {

    log $INFO "Deleting certificate cs-ca-certificate in Installation Namespace"
    oc delete certificate cs-ca-certificate -n $CP4WAIOPS_PROJECT --ignore-not-found=true
    oc delete secret cs-ca-certificate-secret -n $CP4WAIOPS_PROJECT --ignore-not-found=true

    log $INFO "Deleting other cert manager secrets in AIOPS install namespace"
    oc delete secrets  -l operator.ibm.com/watched-by-cert-manager
}

delete_EDB_related_resources() {
    log $INFO "Delete EDB Connection Secret"
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-secret

    log $INFO "Delete EDB Cert related resources"
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-client-cert   
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-server-cert
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-ss-cacert

    oc delete certificaterequest -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-client-cert-1
    oc delete certificaterequest -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-server-cert-1
    oc delete certificaterequest -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-ss-ca-1

    oc delete certificate -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-client-cert
    oc delete certificate -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-server-cert
    oc delete certificate -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-edb-postgres-ss-ca

    log $INFO  "Delete EDB secrets"
    oc delete secret postgresql-operator-controller-manager-config -n $CP4WAIOPS_PROJECT
}

delete_redis_resources() {
    log $INFO "Delete Redis resources in $CP$WAIOPS_PROJECT Namespace"
    oc delete serviceaccount ibm-redis-cp-operator-serviceaccount -n $CP4WAIOPS_PROJECT
    oc delete lease.coordination.k8s.io/ibm-redis-cp-operator -n $CP4WAIOPS_PROJECT
    oc delete configmap ibm-redis-cp-operator -n $CP4WAIOPS_PROJECT

    log $INFO "Delete Redis Secrets"
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-redis-client-cert
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-redis-server-cert
    oc delete secret -n $CP4WAIOPS_PROJECT $INSTALLATION_NAME-redis-ss-cacert

    log $INFO "Delete Leftover Redis Roles and Role Bindings" 
    oc delete -n $CP4WAIOPS_PROJECT role -l "operators.coreos.com/ibm-redis-cp.$CP4WAIOPS_PROJECT"
    oc delete -n $CP4WAIOPS_PROJECT rolebinding -l "operators.coreos.com/ibm-redis-cp.$CP4WAIOPS_PROJECT"
}

cleanBedrockControlPlane() {
    local cpNS=$1

    # Check if control namespace listed from cs map cfgmap exists
    log $INFO "Checking is namespace $cpNS exists"
    oc get ns $cpNS --ignore-not-found

    # if it doesnt exist, return this func
    if [[ "$?" == "1" ]]; then
        return 0
    fi

    log $INFO "Cleaning up IBM Cert Manager from $cpNS namespace"
    unsubscribe "" $cpNS "operators.coreos.com/ibm-cert-manager-operator.$cpNS"

    log $INFO "Cleaning up IBM Namespace Scope Operator from $cpNS namespace"
    oc delete --all namespacescopes.operator.ibm.com -n $cpNS
    unsubscribe "" $cpNS "operators.coreos.com/ibm-namespace-scope-operator.$cpNS"

    # This only happens when we are the only cloud pak. See edge case 1 and 3 in deleteMiscBedrockResources func
    oc delete ns $cpNS
    return 0    
}

deleteBRMappingAndCRDS() {
    local controlNamespace=$1

    # Delete mapping cfgmap
    oc delete cm common-service-maps -n kube-public
    
    # Check control namespace to clean
    if [[ "$controlNamespace" != "" ]]; then
        cleanBedrockControlPlane $controlNamespace
    fi

    # Delete CRDs
    if [[ "${DELETE_CRDS}" == "true" ]]; then
        checkForLeftOverCustomResources "${BEDROCK_CRDS[@]}" "CPFS"

        log $info "Deleting CPFS CRDS" 
        delete_crd_group "BEDROCK_CRDS"
    fi
    return 0
}

deleteMiscBedrockResources() {
    # In  v4, AIOPS is not using a shared instance of commonservices. This needs do be deleted outright.
    log $INFO "Deleting ValidatingWebhookConfiguration"
    oc delete validatingwebhookconfiguration ibm-cs-ns-mapping-webhook-configuration --ignore-not-found

    # controlPlane is the namespace of controlPlane in the mapping configmap
    controlPlane=$(oc get cm -n kube-public common-service-maps -o yaml | grep "controlNamespace" | awk 'NR==1 {print $2}')

    # Check common-service-maps configmap in kube-public ns... This will store any instances of "map-to-common-service-namespace" into an array
    cs_maps=$(oc get cm -n kube-public common-service-maps -o yaml | grep "map-to-common-service-namespace" | grep -v "data" | awk -F: '{print $2}')

    # Edge Case 1: Empty map
    if [[ "$cs_maps" == "" ]]; then
        deleteBRMappingAndCRDS $controlPlane
        return 0
    fi

    # Edge Case #2: cs_maps actually returns some values.
    for map in ${cs_maps[@]}; do
        # Make function return on first occuring item in array that does not equal install namespace
        if [[ "$map" != "$CP4WAIOPS_PROJECT" ]]; then
            log $WARNING "Cloud Pak tenant namespace $map is present on the cluster, so shared resources should not be deleted."
            return 1
        fi
    done

    # Edge Case #3: CS map only contains our namespace
    # Delete the cfgmap
    deleteBRMappingAndCRDS $controlPlane

    oc delete cm cloud-native-postgresql-image-list --ignore-not-found
    return 0
}

checkForLeftOverCustomResources() {
   # Load the all arguments of checkForLeftOverCustomResources
   local CRDS=("$@")
   # Get the last argument of the function
   local last_index=$((${#CRDS[@]}-1))
   local CUSTOM_RESOURCE_TYPE="${CRDS[$last_index]}"
   # Remove the last argument from the array. This is necessary because $CRDS is an array of all arguments
   unset CRDS[$last_index]
   
   resourceCheckCounter=1

   log $INFO "Checking for $CUSTOM_RESOURCE_TYPE custom resources"

    while [[ "${resourceCheckCounter}" -le "4" ]]; do
        # At each iteration start with a fresh RESOURCE_FLAG variable set to false
        RESOURCE_FLAG="false"
    
        # If attempts reach 5, go ahead and end the script
        if [[ "${resourceCheckCounter}" -eq "5" ]]; then
            log $ERROR "Some $CUSTOM_RESOURCE_TYPE CustomResources remain. Please delete them, then restart the script."
            exit 1
        fi

        #  Poll for each CRs for each CRD. If found, set the BR_FLAG to true
        log $INFO "Resource Check Attempt: $resourceCheckCounter"
        for CR in ${CRDS[@]}; do
            echo $CR
            check="$(oc get $CR -A)"
            if [[ -n "${check}" ]]; then
                RESOURCE_FLAG="true"
                oc get $CR -A
                echo
            else
                echo "None Found"
                echo
             fi
        done
        echo

        # After all crds have been searched for, if the RESOURCE_FLAG is still false -- we know all CRDs are safe to delete. We can
        # break out of the while-loop now.
        if [[ "${RESOURCE_FLAG}" == "false" ]]; then
            log $INFO "CRDs from $CUSTOM_RESOURCE_TYPE are safe to be deleted"
            break
        fi

        # Otherwise, resources are still left over. If that's the case, let's try this entire thing after 30 seconds
        echo "CustomResources found... Trying again in 30 seconds."
        resourceCheckCounter=$((resourceCheckCounter + 1))
        sleep 30
    done
}