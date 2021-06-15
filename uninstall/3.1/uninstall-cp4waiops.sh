#!/bin/sh
#
# Copyright 2020- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
# This script can be used to uninstall the Cloud Pak for Watson AIOps product and
# cleanup resources created by the product.  Please configure what you want to uninstall
# in the uninstall-cp4waiops-props.sh file first before running this script.

. ./uninstall-cp4waiops-props.sh
. ./uninstall-cp4waiops-helper.sh
. ./uninstall-cp4waiops-resource-groups.sh

HELP="false"
SKIP_CONFIRM="false"
DRY_RUN="false"

while getopts 'hs' OPTION; do
  case "$OPTION" in
    h)
      HELP="true"    
      ;;
    s)
      SKIP_CONFIRM="true"
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [[ $HELP == "true" ]]; then
  display_help
  exit 0
fi 

analyze_script_properties

# Confirm we really want to uninstall 
if [[ $SKIP_CONFIRM != "true" ]]; then
  log $INFO
  log $INFO "This script will uninstall IBM Cloud Pak for AIOps. Please ensure you have deleted any CRs you created before running this script."
  log $INFO ""
  log $INFO "##### IMPORTANT ######"
  log $INFO ""
  log $INFO "Please review and update the contents of uninstall-cp4waiops-props.sh carefully to configure what you want to delete before proceeding."
  log $INFO "Data loss is possible if uninstall-cp4waiops-props.sh is not reviewed and configured carefully."
  log $INFO ""
  log $INFO "Cluster context: $(oc config current-context)"
  log $INFO ""
  display_script_properties
  read -p "Please confirm you have reviewed and configured uninstall-cp4waiops-props.sh and would like to proceed with install. Y or y to continue: " -n 1 -r
  log $INFO
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log $INFO "Cancelling uninstall of IBM Cloud Pak for AIOps."
    exit 0
  fi
else
  log $INFO
  log $INFO "This script will uninstall IBM Cloud Pak for AIOps."
  display_script_properties
  log $INFO ""
fi 

# Verify prereqs: oc is installed & we are logged into the cluster already
if ! [ -x "$(command -v oc)" ]; then
  log $ERROR "oc CLI is not installed.  Please install the oc CLI and try running the script again."
  exit 1
fi

oc project
if [ $? -gt 0 ]; then
  log $ERROR "oc login required.  Please login to the cluster and try running the script again."
  exit 1
fi

echo
log $INFO "Prereq checks passed. Starting uninstall of Cloud Pak for Watson AIOps ..."
echo

# Check if the project configured in the props file exists
if [[ ! -z "$AIOPS_PROJECT"  ]]; then 
   # Delete the installation CR
	log $INFO "Deleting the installation CR..."
	delete_installation_instance $INSTALLATION_CR_NAME $AIOPS_PROJECT
	check_additional_installation_exists

   # Then delete the CP4AIOps CRDs
   log $INFO "Deleting the CP4WAIops CRDs..."
   delete_crd_group "CP4WAIOPS_CRDS"

   # If user configred to delete Kong, then delete those CRDs.
   # The operator & CRs will be deleted automatically by deletion of installation CR
   if [[ $DELETE_KONG_CRDS == "true" ]]; then   
      log $INFO "Deleting the Kong CRDs..."
      delete_crd_group "KONG_CRDS"
   else
      log $INFO "Skipping delete of Kong CRDs based on configuration in uninstall-cp4waiops-props.sh"
   fi

   # If user configred to delete Camel K, then delete those CRDs.
   # The operator & CRs will be deleted automatically by deletion of installation CR
   if [[ $DELETE_CAMELK_CRDS == "true" ]]; then   
      log $INFO "Deleting the Camel K CRDs..."
      delete_crd_group "CAMELK_CRDS"
   else
      log $INFO "Skipping delete of Camel K CRDs based on configuration in uninstall-cp4waiops-props.sh"
   fi

   # Finally uninstall the CP4WAIOps operator by deleting the subscription & CSV
   log $INFO "Uninstalling the CP4WAIOps operator..."
	unsubscribe "ibm-aiops-orchestrator" $OPERATORS_NAMESPACE ""

   # Now verify from user input that there are no other cloud paks in this project
   # If there aren't and user confirms they want to delete zenservice, start that process
   if [[ $DELETE_ZENSERVICE == "true" ]]; then
    #First delete the AutomationUIConfig / AutomationBase if present, that were created by users.
    log $INFO "Deleting the AutomationUIConfig if present"
    oc delete AutomationUIConfig --all -n $AIOPS_PROJECT --ignore-not-found
    log $INFO "Deleting the AutomationBase if present"
    oc delete AutomationBase --all -n $AIOPS_PROJECT --ignore-not-found
    
    # Then delete the zenservice instance
   	log $INFO "Deleting the zenservice CR..."
   	delete_zenservice_instance $ZENSERVICE_CR_NAME $AIOPS_PROJECT

      log $INFO "Deleting IAF configmaps in $AIOPS_PROJECT"
      for CONFIGMAP in ${IAF_CONFIGMAPS[@]}; do
            log $INFO "Deleting configmap $CONFIGMAP.."
            oc delete $CONFIGMAP -n $AIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting IAF secrets in $AIOPS_PROJECT"
      for SECRET in ${IAF_SECRETS[@]}; do
            log $INFO "Deleting secret $SECRET.."
            oc delete $SECRET -n $AIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting IAF certs in $AIOPS_PROJECT"
      for CERT in ${IAF_CERTMANAGER[@]}; do
            log $INFO "Deleting cert $CERT.."
            oc delete $CERT -n $AIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting leftover IAF resources in $AIOPS_PROJECT"
      for RESOURCE in ${IAF_MISC[@]}; do
            log $INFO "Deleting $RESOURCE.."
            oc delete $RESOURCE -n $AIOPS_PROJECT --ignore-not-found
      done
   else
      log $INFO "Skipping delete of zenservice based on configuration in uninstall-cp4waiops-props.sh"
	fi

   # Start cleaning up remaining resources in the project that CP4WAIOps created 
   # and are not automatically deleted when CR is deleted
   log $INFO "Deleting kafkatopics in $AIOPS_PROJECT"
   for KAFKATOPIC in ${CP4AIOPS_KAFKATOPICS[@]}; do
         log $INFO "Deleting kafkatopic $KAFKATOPIC..."
         oc delete $KAFKATOPIC -n $AIOPS_PROJECT --ignore-not-found
   done

   log $INFO "Deleting lease in $AIOPS_PROJECT"
   for LEASE in ${CP4AIOPS_LEASE[@]}; do
         log $INFO "Deleting lease $LEASE.."
         oc delete $LEASE -n $AIOPS_PROJECT --ignore-not-found
   done

   # Confirm with user we want to delete configmaps
   if [[ $DELETE_CONFIGMAPS == "true" ]]; then
      log $INFO "Deleting leftover configmaps in $AIOPS_PROJECT"
      for CONFIGMAP in ${CP4AIOPS_CONFIGMAPS[@]}; do
            log $INFO "Deleting configmap $CONFIGMAP.."
            oc delete $CONFIGMAP -n $AIOPS_PROJECT --ignore-not-found
      done
   fi

   # Confirm with user we want to delete PVCs
   if [[ $DELETE_PVCS == "true" ]]; then
      log $INFO "Deleting PVCs in $AIOPS_PROJECT"
      for PVC in ${CP4AIOPS_PVC_LABEL[@]}; do
            log $INFO "Deleting PVCs with label $PVC.."
            oc delete pvc -l $PVC -n $AIOPS_PROJECT --ignore-not-found
      done
   fi

   # Confirm with user we want to delete secrets
   if [[ $DELETE_SECRETS == "true" ]]; then
      log $INFO "Deleting secrets in $AIOPS_PROJECT"
      for SECRET in ${CP4AIOPS_SECRETS[@]}; do
            log $INFO "Deleting secret $SECRET.."
            oc delete $SECRET -n $AIOPS_PROJECT --ignore-not-found
      done
   fi

   # If both DELETE_PVCS=true and DELETE_SECRETS=true then only delete these secrets category
   if [[ ( $DELETE_SECRETS == "true" ) && ( $DELETE_PVCS == "true" ) ]]; then
       log $INFO "Deleting secrets from group CP4AIOPS_PVC_SECRETS in $AIOPS_PROJECT"
       for SECRET in ${CP4AIOPS_PVC_SECRETS[@]}; do
            log $INFO "Deleting secret $SECRET.."
            oc delete $SECRET -n $AIOPS_PROJECT --ignore-not-found
      done
   fi

   # At this point we have cleaned up everything in the project

   # If user wants to delete the project, do that now
   if [[ $DELETE_AIOPS_PROJECT == "true" ]]; then
      log $INFO "Deleting project $AIOPS_PROJECT"
      delete_project $AIOPS_PROJECT
   else
      log $INFO "Skipping delete of $AIOPS_PROJECT project based on configuration in uninstall-cp4waiops-props.sh"
   fi

   # Finally uninstall & cleanup resources created at cluster scope & other projects 
   # if user confirms they have no other cloud paks on the cluster and want to do a full uninstall
   if [[ $DELETE_IAF == "true" ]]; then
      log $INFO "Deleting IAF"
      delete_iaf_bedrock

      log $INFO "Deleting IAF PVCs in $AIOPS_PROJECT"
      for PVC in ${IAF_PVCS[@]}; do
            log $INFO "Deleting PVC $PVC.."
            oc delete $PVC -n $AIOPS_PROJECT --ignore-not-found
      done

   else
      log $INFO "Skipping delete of IAF based on configuration in uninstall-cp4waiops-props.sh"
   fi
else
   log $ERROR "AIOPS_PROJECT not set. Please specify project and try again."
   display_help
   exit 1
fi