#!/bin/bash
#
# Copyright 2020- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
. ./uninstall-cp4waiops-props.sh

export OPERATORS_NAMESPACE=openshift-operators
export IBM_COMMON_SERVICES_NAMESPACE=ibm-common-services
export KNATIVE_SERVING_NAMESPACE=knative-serving
export KNATIVE_EVENTING_NAMESPACE=knative-eventing
export ZENSERVICE_CR_NAME=iaf-zen-cpdservice

# SLEEP TIMES
SLEEP_SHORT_LOOP=5s
SLEEP_MEDIUM_LOOP=15s
SLEEP_LONG_LOOP=30s
SLEEP_EXTRA_LONG_LOOP=40s

# Tracing prefixes
INFO="[INFO]"
WARNING="[WARNING]"
ERROR="[ERROR]"

log () {
   local log_tracing_prefix=$1
   local log_message=$2
   local log_options=$3
    
   if [[ ! -z $log_options ]]; then
      echo $log_options "$log_tracing_prefix $log_message"
   else
      echo "$log_tracing_prefix $log_message" 
   fi
}

display_help() {
   echo "**************************************** Usage ********************************************"
   echo ""
   echo " This script is used to uninstall Cloud Pak for Watson AIOps."
   echo " The following prereqs are required before you run this script: "
   echo " - oc CLI is installed and you have logged into the cluster using oc login"
   echo " - Update uninstall-cp4waiops-props.sh with components that you want to uninstall"
   echo ""
   echo " Usage:"
   echo " ./uninstall-cp4waiops.sh -h -s"
   echo "  -h Prints out the help message"
   echo "  -s Skip asking for confirmations"   
   echo ""
   echo "*******************************************************************************************"
}

check_oc_resource_exists() {
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
       operator_exists=$( check_oc_resource_exists "subscription.operators.coreos.com" $operator_name $dest_namespace )
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
            log $WARNING "The ClusterServiceVersion for the operator $operator_name does not exists, skipping the deletion of the ClusterServiceVersion for operator $operator_name"
        fi

    else
        log $WARNING "The subscription for the operator $operator_name does not exists, skipping the unsubscription of the operator $operator_name"
    fi
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

        log $INFO "Checking if operandrequests are all deleted "
        while [ `oc get operandrequests ibm-aiops-ai-manager -n $project --ignore-not-found --no-headers |  wc -l` -gt 0 ] || 
                [ `oc get operandrequests ibm-aiops-aiops-foundation -n $project --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
                [ `oc get operandrequests ibm-aiops-application-manager  -n $project --ignore-not-found --no-headers |  wc -l` -gt 0 ]  ||
                [ `oc get operandrequests iaf-system-common-service -n $project --ignore-not-found --no-headers |  wc -l` -gt 0 ]
        do
        sleep $SLEEP_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 20 ] ; then
            log $ERROR "Timed out waiting for operandrequests to be deleted"
            exit 1
        else
            log $INFO "Found following operandrequests in the project: "
            log $INFO "$(oc get operandrequests -n $project --no-headers)"
            log $INFO "Waiting for operandrequests instances to get deleted... Checking again in $SLEEP_LONG_LOOP seconds"
        fi
        done
        log $INFO "Expected operandrequests got deleted successfully!"

    else
        log $INFO "The $installation_name installation instance is not found, skipping the deletion of $installation_name."
    fi

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
        while [ `oc get operandrequests ibm-commonui-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-iam-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-mongodb-request -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests management-ingress -n ibm-common-services --ignore-not-found --no-headers |  wc -l` -gt 0 ] ||
              [ `oc get operandrequests platform-api-request -n ibm-common-services --ignore-not-found --no-headers|  wc -l` -gt 0 ] ||
              [ `oc get operandrequests ibm-iam-service -n ${project} --ignore-not-found --no-headers |  wc -l` -gt 0 ]
        do
        sleep $SLEEP_LONG_LOOP
        LOOP_COUNT=`expr $LOOP_COUNT + 1`
        if [ $LOOP_COUNT -gt 10 ] ; then
            log $ERROR "Timed out waiting for operandrequests to be deleted"
            exit 1
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

        if [ `oc get operandrequests -n $project --ignore-not-found --no-headers|  wc -l` -gt 0 ]; then
            log $ERROR "Found operandrequests in the project.  Please review the remaining operandrequests before deleting the project."
            exit 0
        fi

        if [ `oc get cemprobes -n $project --ignore-not-found --no-headers|  wc -l` -gt 0 ]; then
            log $ERROR "Found cemprobes in the project.  Please review the remaining cemprobes before deleting the project."
            exit 0
        fi

        oc patch -n $project rolebinding/admin -p '{"metadata": {"finalizers":null}}'

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
    log $INFO "Starting uninstall of IAF & Bedrock components"
    oc patch -n ibm-common-services rolebinding/admin -p '{"metadata": {"finalizers":null}}'
    oc delete rolebinding admin -n ibm-common-services --ignore-not-found

    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation-ai.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation-core.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation-elastic.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation-eventprocessing.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation-flink.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-automation.openshift-operators"
    unsubscribe "" $OPERATORS_NAMESPACE "operators.coreos.com/ibm-common-service-operator.openshift-operators"
                   

    oc delete operandrequest iaf-operator -n openshift-operators --ignore-not-found
    oc delete operandrequest iaf-core-operator -n openshift-operators --ignore-not-found

    # Note :  Verify there are no operandrequests & operandbindinfo at this point before proceeding.  It may take a few minutes for them to go away.
    log $INFO "Checking if operandrequests are all deleted "
    while [ `oc get operandrequests -A --ignore-not-found --no-headers|  wc -l` -gt 0 ]
    do
    sleep $SLEEP_LONG_LOOP
    LOOP_COUNT=`expr $LOOP_COUNT + 1`
    if [ $LOOP_COUNT -gt 30 ] ; then
        log $ERROR "Timed out waiting for all operandrequests to be deleted.  Cannot proceed with uninstallation til all operandrequests in ibm-common-services project are deleted."
        exit 1
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

    unsubscribe "ibm-cert-manager-operator" $IBM_COMMON_SERVICES_NAMESPACE ""
    unsubscribe "ibm-namespace-scope-operator" $IBM_COMMON_SERVICES_NAMESPACE ""
    unsubscribe "operand-deployment-lifecycle-manager-app" $IBM_COMMON_SERVICES_NAMESPACE ""

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

    oc delete apiservice v1beta1.webhook.certmanager.k8s.io --ignore-not-found
    oc delete apiservice v1.metering.ibm.com --ignore-not-found

    oc delete ValidatingWebhookConfiguration cert-manager-webhook --ignore-not-found
    oc delete MutatingWebhookConfiguration cert-manager-webhook ibm-common-service-webhook-configuration namespace-admission-config --ignore-not-found

    delete_project $IBM_COMMON_SERVICES_NAMESPACE

    delete_crd_group "IAF_CRDS"
    delete_crd_group "BEDROCK_CRDS"
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
    "KONG_CRDS") 
        for CRD in ${KONG_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "CAMELK_CRDS") 
        for CRD in ${CAMELK_CRDS[@]}; do
            log $INFO "Deleting CRD $CRD.."
            oc delete crd $CRD --ignore-not-found
        done
    ;;
    "IAF_CRDS") 
        for CRD in ${IAF_CRDS[@]}; do
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
    esac
}

analyze_script_properties(){

if [[ $DELETE_ALL == "true" ]]; then
   DELETE_PVCS="true"
   DELETE_SECRETS="true"
   DELETE_CONFIGMAPS="true"
   DELETE_KONG_CRDS="true"
   DELETE_CAMELK_CRDS="true"
   DELETE_ZENSERVICE="true"
   DELETE_AIOPS_PROJECT="true"
   DELETE_IAF="true"
fi

}

display_script_properties(){

log $INFO "##### Properties in uninstall-cp4waiops-props.sh #####"
log $INFO
if [[ $DELETE_ALL == "true" ]]; then
	log $INFO "The script uninstall-cp4waiops-props.sh has 'DELETE_ALL=true', hence the script will execute wih below values: "
else
    log $INFO "The script uninstall-cp4waiops-props.sh has the properties with below values: "
fi
log $INFO "AIOPS_PROJECT=$AIOPS_PROJECT"
log $INFO "INSTALLATION_CR_NAME=$INSTALLATION_CR_NAME"
log $INFO "DELETE_PVCS=$DELETE_PVCS"
log $INFO "DELETE_SECRETS=$DELETE_SECRETS"
log $INFO "DELETE_CONFIGMAPS=$DELETE_CONFIGMAPS"
log $INFO "DELETE_KONG_CRDS=$DELETE_KONG_CRDS"
log $INFO "DELETE_CAMELK_CRDS=$DELETE_CAMELK_CRDS"
log $INFO "DELETE_ZENSERVICE=$DELETE_ZENSERVICE"
log $INFO "DELETE_AIOPS_PROJECT=$DELETE_AIOPS_PROJECT"
log $INFO "DELETE_IAF=$DELETE_IAF"
log $INFO
log $INFO "##### Properties in uninstall-cp4waiops-props.sh #####"
}

check_additional_installation_exists(){

  log $INFO "Checking if any additional installation resources found in the cluster."
  installation_returned_value=$(oc get installations.orchestrator.aiops.ibm.com -A)
  if [[ ! -z $installation_returned_value  ]] ; then
     log $ERROR "Some additional installation cr found in the cluster, please delete the installation cr's and try again."
     log $ERROR "Remaining installation cr found : "
     oc get installations.orchestrator.aiops.ibm.com -A
     exit 1
  else
     log $INFO "No additional installation resources found in the cluster."
  fi
}
