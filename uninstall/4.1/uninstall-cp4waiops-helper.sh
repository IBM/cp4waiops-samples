#!/bin/bash
#
# Copyright 2020- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
. ./uninstall-cp4waiops.props

export OPERATORS_PROJECT=openshift-operators
export IBM_COMMON_SERVICES_PROJECT=ibm-common-services
export ZENSERVICE_CR_NAME=iaf-zen-cpdservice

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
   echo " This script is used to uninstall IBM Cloud Pak for Watson AIOps AI Manager version 4.1"
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
        #oc delete subscription.operators.coreos.com $operator_name -n $dest_namespace
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
	          log $INFO "Trying to delete remaining operandrequests manually, only for Watson Aiops"
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

delete_zenservice_instance () {
    local zenservice_name=$1
    local project=$2

    if  [ `oc get zenservice $zenservice_name -n $project --ignore-not-found | wc -l` -gt 0 ] ; then
        log $INFO "Found zenservice CR $zenservice_name to delete."

        oc delete zenservice $zenservice_name -n $project --ignore-not-found;
    
        log $INFO "Waiting for $resource instances to be deleted...."
        LOOP_COUNT=0
        while [ `oc get zenservice $zenservice_name -n $project --ignore-not-found | wc -l` -gt 0 ]
        do
        sleep $SLEEP_EXTRA_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 20 ] ; then
            log $ERROR "Timed out waiting for zenservice instance $zenservice_name to be deleted"
            exit 1
        else
            log $INFO "Waiting for zenservice instance to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "$zenservice_name instance got deleted successfully!"

        log $INFO "Checking if operandrequests are all deleted "
        LOOP_COUNT=0
        while [ `oc get operandrequests ibm-commonui-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-iam-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-mongodb-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests management-ingress -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests platform-api-request -n ibm-common-services --ignore-not-found --no-headers|  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-iam-service -n ${project} --ignore-not-found --no-headers |  wc -l` -gt 0 ]
        do
        sleep $SLEEP_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 15 ] ; then
            log $ERROR "Timed out waiting for operandrequests to be deleted"
            exit 1
        elif [ "$LOOP_COUNT" == "10" ] ; then
            oc delete operandrequest -n ibm-common-services ibm-commonui-request
        else
            log $INFO "Found following operandrequests in the project: "
            log $INFO "$(oc get operandrequests -n ibm-common-services --no-headers)"
            log $INFO "Waiting for zenservice related operandrequests instances to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "Expected operandrequests got deleted successfully!"

    else
        log $INFO "The $zenservice_name zenservice instance is not found, skipping the deletion of $zenservice_name."
    fi

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

delete_iaf_bedrock () {
    log $INFO "Starting uninstall of Bedrock components"

    # Delete Bedrock/Common Services from the projects they were installed in. 
    # This is a full removal of Bedrock/Common Services operators, resources, and CRDS.

    if [ $ONLY_CLOUDPAK == "true" ]; then 

        oc patch -n $CP4WAIOPS_PROJECT rolebinding/admin -p '{"metadata": {"finalizers":null}}' 2>>/dev/null

        oc patch -n $IBM_COMMON_SERVICES_PROJECT rolebinding/admin -p '{"metadata": {"finalizers":null}}' 2>>/dev/null
        oc delete rolebinding admin -n $IBM_COMMON_SERVICES_PROJECT --ignore-not-found
        oc patch -n $IBM_COMMON_SERVICES_PROJECT rolebinding/edit -p '{"metadata": {"finalizers":null}}' 2>>/dev/null
        oc delete rolebinding edit -n $IBM_COMMON_SERVICES_PROJECT --ignore-not-found
        oc patch -n $IBM_COMMON_SERVICES_PROJECT rolebinding/view -p '{"metadata": {"finalizers":null}}' 2>>/dev/null
        oc delete rolebinding view -n $IBM_COMMON_SERVICES_PROJECT --ignore-not-found

        subscription_check=$(oc get subscription.operators.coreos.com -n $CP4WAIOPS_PROJECT -l operators.coreos.com/ibm-automation-elastic.$CP4WAIOPS_PROJECT --ignore-not-found)
        if [[ "$subscription_check" == "" ]]; then
            unsubscribe "" $OPERATORS_PROJECT "operators.coreos.com/ibm-automation-elastic.$OPERATORS_PROJECT"
        else
            unsubscribe "" $CP4WAIOPS_PROJECT "operators.coreos.com/ibm-automation-elastic.$CP4WAIOPS_PROJECT"
        fi

        subscription_check=$(oc get subscription.operators.coreos.com -n $CP4WAIOPS_PROJECT -l operators.coreos.com/ibm-automation-flink.$CP4WAIOPS_PROJECT --ignore-not-found)
        if [[ "$subscription_check" == "" ]]; then
            unsubscribe "" $OPERATORS_PROJECT "operators.coreos.com/ibm-automation-flink.$OPERATORS_PROJECT"
        else
            unsubscribe "" $CP4WAIOPS_PROJECT "operators.coreos.com/ibm-automation-flink.$CP4WAIOPS_PROJECT"
        fi

        subscription_check=$(oc get subscription.operators.coreos.com -n $CP4WAIOPS_PROJECT -l operators.coreos.com/ibm-common-service-operator.$CP4WAIOPS_PROJECT --ignore-not-found)
        if [[ "$subscription_check" == "" ]]; then
            unsubscribe "" $OPERATORS_PROJECT "operators.coreos.com/ibm-common-service-operator.$OPERATORS_PROJECT"
        else
            unsubscribe "" $CP4WAIOPS_PROJECT "operators.coreos.com/ibm-common-service-operator.$CP4WAIOPS_PROJECT"
        fi
              
        # Note :  Verify there are no operandrequests & operandbindinfo at this point before proceeding.  It may take a few minutes for them to go away.
        log $INFO "Checking if operandrequests are all deleted "
        LOOP_COUNT=0
        while [ `oc get operandrequests -A --ignore-not-found --no-headers | wc -l ` -gt 0 ]
        do
        sleep $SLEEP_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 30 ]; then
            log $ERROR "Timed out waiting for all operandrequests to be deleted.  Cannot proceed with uninstallation til all operandrequests in ibm-common-services project are deleted."
            exit 1
        elif [ "$LOOP_COUNT" == "15" ]; then
            oc delete --all operandrequests -n ibm-common-services
            oc delete --all operandrequests -n $CP4WAIOPS_PROJECT       
        else
            log $INFO "Found following operandrequests in the project: $(oc get operandrequests -A --ignore-not-found --no-headers)"
            log $INFO "Waiting for operandrequests instances to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "Expected operandrequests got deleted successfully!"

        # Deleting operandbindinfo before namespacescopes as seen in iaf internal uninstall script
        oc delete operandbindinfo --all -n ibm-common-services --ignore-not-found
        oc delete namespacescopes common-service -n ibm-common-services --ignore-not-found
        oc delete namespacescopes nss-managedby-odlm -n ibm-common-services --ignore-not-found
        oc delete namespacescopes odlm-scope-managedby-odlm -n ibm-common-services --ignore-not-found
        oc delete namespacescopes nss-odlm-scope -n ibm-common-services --ignore-not-found

        unsubscribe "ibm-cert-manager-operator" $IBM_COMMON_SERVICES_PROJECT ""
        unsubscribe "ibm-namespace-scope-operator" $IBM_COMMON_SERVICES_PROJECT ""
        unsubscribe "operand-deployment-lifecycle-manager-app" $IBM_COMMON_SERVICES_PROJECT ""

        log $INFO "Checking that Cloud Pak Platform subscriptions have successfully been removed..."
        if [ `oc get subs -A | grep -E 'ibm-automation|ibm-cert|ibm-namespace|operand-deployment' | wc -l` -gt 0 ]; then
            log $ERROR "Some subscriptions for Cloud Pak Platform components remain. Please delete them and try again."
            exit 1
        fi
        log $INFO "...Cloud Pak Platform Subscriptions removed successfully."

        oc delete deployment cert-manager-cainjector -n ibm-common-services --ignore-not-found
        oc delete deployment cert-manager-controller -n ibm-common-services --ignore-not-found
        oc delete deployment cert-manager-webhook -n ibm-common-services --ignore-not-found
        oc delete deployment configmap-watcher -n ibm-common-services --ignore-not-found
        oc delete deployment ibm-common-service-webhook -n ibm-common-services --ignore-not-found
        oc delete deployment meta-api-deploy -n ibm-common-services --ignore-not-found
        oc delete deployment secretshare -n ibm-common-services --ignore-not-found

        oc delete service cert-manager-webhook -n ibm-common-services --ignore-not-found
        oc delete service ibm-common-service-webhook -n ibm-common-services --ignore-not-found
        oc delete service meta-api-svc -n ibm-common-services --ignore-not-found
        oc get role.rbac.authorization.k8s.io --no-headers -o name | grep nss-runtime-managed-role-from-ibm-common-services | while read a b; do oc delete "$a"; done

        # IAF uninstall instructions say to delete all deployments and services
        oc delete deployment --all -n $IBM_COMMON_SERVICES_PROJECT
        oc delete services --all -n $IBM_COMMON_SERVICES_PROJECT

        oc delete apiservice v1beta1.webhook.certmanager.k8s.io --ignore-not-found
        oc delete apiservice v1.metering.ibm.com --ignore-not-found

        oc delete ValidatingWebhookConfiguration cert-manager-webhook --ignore-not-found
        oc delete MutatingWebhookConfiguration cert-manager-webhook ibm-common-service-webhook-configuration namespace-admission-config --ignore-not-found

        oc delete --ignore-not-found $(oc get crd -o name | grep "serving.kubeflow.org" || echo "crd no-serving-kubeflow")

        # TODO (3/23/23): We may need to keep "delete_crd_group "IAF_CRDS"" to delete elasticsearches and flinkclusters
        delete_crd_group "IAF_CRDS"
        delete_crd_group "BEDROCK_CRDS"

        oc patch -n $IBM_COMMON_SERVICES_PROJECT rolebindings.authorization.openshift.io/bedrock-admin -p '{"metadata": {"finalizers":null}}' 2>>/dev/null
        oc patch -n $IBM_COMMON_SERVICES_PROJECT rolebindings.rbac.authorization.k8s.io/bedrock-admin -p '{"metadata": {"finalizers":null}}' 2>>/dev/null

        delete_project $IBM_COMMON_SERVICES_PROJECT

    fi
}

delete_crd_group () {
    local crd_group=$1

    case "$crd_group" in
    "CP4WAIOPS_CRDS") 
        for CRD in ${CP4WAIOPS_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "CP4WAIOPS_DEPENDENT_CRDS") 
        for CRD in ${CP4WAIOPS_DEPENDENT_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "IAF_CRDS") 
        log $INFO "Deleting IAF CRDs.."
        oc delete --ignore-not-found $(oc get crd -o name | grep "automation.ibm.com" || echo "crd no-automation-ibm")
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

if [[ $ONLY_CLOUDPAK != "true" ]] && [[ $ONLY_CLOUDPAK != "false" ]]; then
    log $ERROR "The ONLY_CLOUDPAK flag must have a value of either \"true\" or \"false\". Please review the uninstall-cp4waiops.props file."
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
log $INFO "ONLY_CLOUDPAK=\033[1;36m$ONLY_CLOUDPAK\033[0m"
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

check_additional_asm_exists(){
    log $INFO "Checking if any additional ASM resources (ie from Event Manager installation) are on the cluster."
    if [ `oc get asms.asm.ibm.com -A --no-headers | while read a b; do echo $a | grep -vw $CP4WAIOPS_PROJECT; done | wc -l`  -gt 0 ] ||
     [ `oc get asmformations.asm.ibm.com -A --no-headers | while read a b; do echo $a | grep -vw $CP4WAIOPS_PROJECT; done | wc -l` -gt 0 ] ; then
        log $INFO "ASM resource instances were found outside the $CP4WAIOPS_PROJECT namespace"
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
    # Securetunnel secrets are removed via resource group CP4WAIOPS_INTERNAL_SECRETS
}

delete_IRCoreResources(){
    # Get the name of the leftover IR Core resource
    IRCoreName=$(oc get Role | grep ibm-aiops-ir-core | awk '{ print $1 }')

    oc delete role/$IRCoreName --ignore-not-found
    oc delete rolebinding/$IRCoreName --ignore-not-found
}

delete_crossplane(){
    oc get csv -n $IBM_COMMON_SERVICES_PROJECT --no-headers -o name | grep "crossplane" | while read a b; do oc delete "$a" -n $IBM_COMMON_SERVICES_PROJECT --ignore-not-found; done
    oc delete sub ibm-crossplane-operator-app -n $IBM_COMMON_SERVICES_PROJECT --ignore-not-found

    log $INFO "Delete the Crossplane custom resources"
    # remove finalizers from and delete kafkaclaim, configurationrevisions, composition, objects, provider configs
    log $INFO "Deleting kafkaclaims in $CP4WAIOPS_PROJECT"
    for KAFKACLAIM in ${CROSSPLANE_KAFKACLAIMS[@]}; do
      log $INFO "Deleting $KAFKACLAIM..."
      oc patch -n $CP4WAIOPS_PROJECT $KAFKACLAIM --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
      oc delete $KAFKACLAIM -n $CP4WAIOPS_PROJECT --ignore-not-found
    done

    log $INFO "Deleting Object resources at the cluster scope"
    for OBJECT in ${CROSSPLANE_OBJECTS[@]}; do
      log $INFO "Deleting $OBJECT..."
      oc patch $OBJECT --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
      oc delete $OBJECT --ignore-not-found
    done

    log $INFO "Deleting configurations at the cluster scope"
    oc delete configuration.pkg.ibm.crossplane.io/ibm-crossplane-bedrock-shim-config --ignore-not-found
    log $INFO "Deleting configurationrevisions at the cluster scope"
    oc patch configurationrevision.pkg.ibm.crossplane.io/ibm-crossplane-bedrock-shim-config-ibm-crosspla --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]' && oc delete configurationrevision.pkg.ibm.crossplane.io/ibm-crossplane-bedrock-shim-config-ibm-crosspla --ignore-not-found
    
    log $INFO "Deleting compositions at the cluster scope"
    for COMPOSITION in ${CROSSPLANE_COMPOSITIONS[@]}; do
      log $INFO "Deleting crossplane composition $COMPOSITION.."
      oc delete $COMPOSITION --ignore-not-found
    done
    log $INFO "Deleting ProviderConfig at the cluster scope"
    oc patch providerconfig.kubernetes.crossplane.io/kubernetes-provider --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]' && oc delete providerconfig.kubernetes.crossplane.io/kubernetes-provider --ignore-not-found
    log $INFO "Removing finalizers from cluster scoped lock"
    oc patch lock.pkg.ibm.crossplane.io lock -p '{"metadata":{"finalizers": []}}' --type=merge

    log $INFO "Deleting compositeresourcedefinitions at the cluster scope"
    for XRD in ${CROSSPLANE_XRDS[@]}; do
      oc patch $XRD --type=json --patch='[ { "op": "remove", "path": "/metadata/finalizers" } ]'
      oc delete $XRD --ignore-not-found
    done

    log $INFO "Delete the Crossplane user management resources"
    for RESOURCE in role rolebinding serviceaccount; do oc get $RESOURCE -A --no-headers -o name; done | grep crossplane | while read a b; do oc delete "$a" -n $IBM_COMMON_SERVICES_PROJECT; done
    for RESOURCE in clusterrole clusterrolebinding; do oc get $RESOURCE -A --no-headers -o name; done | grep crossplane | while read a b; do oc delete "$a"; done
}