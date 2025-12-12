#!/bin/bash
#
# © Copyright IBM Corp. 2020, 2025
# SPDX-License-Identifier: Apache2.0
#
# This script can be used to uninstall the IBM Cloud Pak for AIOps v4.12 product and
# cleanup resources created by the product.  Please configure what you want to uninstall
# in the uninstall-cp4waiops.props file first before running this script.

. ./uninstall-cp4waiops.props
. ./uninstall-cp4waiops-helper.sh
. ./uninstall-cp4waiops-resource-groups.props

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
  log $INFO "\033[0;33mUninstall v2.0 for AIOPs v4.12\033[0m"
  log $INFO
  log $INFO "This script will uninstall IBM Cloud Pak for AIOps version 4.12. Please ensure you have deleted any CRs you created before running this script."
  log $INFO ""
  log $INFO "##### IMPORTANT ######"
  log $INFO ""
  log $INFO "Please review and update the contents of uninstall-cp4waiops.props carefully to configure what you want to delete before proceeding."
  log $INFO "CAUTION: Data loss is possible if uninstall-cp4waiops.props is not reviewed and configured carefully."
  log $INFO ""
  log $INFO "Cluster context: $(oc config current-context)"
  log $INFO "Target namespace: ${CP4WAIOPS_PROJECT}"
  log $INFO ""
  display_script_properties
  read -p "Please confirm you have reviewed and configured uninstall-cp4waiops.props and would like to proceed with uninstall. Y or y to continue: " -n 1 -r
  log " "
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log $INFO "Cancelling uninstall of IBM Cloud Pak for AIOps."
    exit 0
  fi
  log " "
else
  log $INFO "\033[0;33mUninstall v2.0 for AIOPs v4.12\033[0m"
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

detectMultiInstanceAndToggle
check_namespaced_install

oc project
if [ $? -gt 0 ]; then
  log $ERROR "oc login required.  Please login to the cluster and try running the script again."
  exit 1
fi

echo
log $INFO "Prereq checks passed. Starting uninstall of IBM Cloud Pak for AIOps ..."
echo

# Check if the project configured in the props file exists
if [[ ! -z "$CP4WAIOPS_PROJECT"  ]]; then 
   log $INFO "Checking if user created instances are found..."
   # Verify if there are manually created instances for below crds by the user and exit in that case.
   aiops_custom_instance_exists $CP4WAIOPS_PROJECT
   if [[ $custom_instance_exists == "true" ]]; then   
      log $ERROR "Some of the user created custom resource instances are present in the namespace $CP4WAIOPS_PROJECT, listing them"
      oc get kongs.management.ibm.com -o name -n $CP4WAIOPS_PROJECT --ignore-not-found --no-headers
      oc get eventmanagergateways.ai-manager.watson-aiops.ibm.com -o name -n $CP4WAIOPS_PROJECT --ignore-not-found --no-headers
      log $ERROR "Please delete them manually before running the uninstall script."
      exit 1
  fi
  log $INFO "No remaining user-created instances, proceeding ahead..."
   
   # Cleanup remaining connections
   delete_connections
 
   # Delete the installation CR
	log $INFO "Deleting the installation CR..."
	delete_installation_instance $INSTALLATION_NAME $CP4WAIOPS_PROJECT
   
   log $INFO "Deleting the misc resources in $CP4WAIOPS_PROJECT "
   for RESOURCE_MISC in ${CP4AIOPS_MISC[@]}; do
      log $INFO "Deleting resource  $RESOURCE_MISC.."
      oc delete $RESOURCE_MISC -n $CP4WAIOPS_PROJECT --ignore-not-found
   done
   
   delete_securetunnel
   
   # Finally uninstall the CP4AIOps operator by deleting the subscription & CSV
   log $INFO "Uninstalling the CP4AIOps operator..."
   # Check if namespace scoped install. If namespaced, pass in CP4WAIOPS_PROJECT, else OPERATORS_PROJECT
   if [[ $AIOPS_NAMESPACED == "true" ]] ; then
      unsubscribe "ibm-aiops-orchestrator" $CP4WAIOPS_PROJECT ""
   else
	   unsubscribe "ibm-aiops-orchestrator" $OPERATORS_PROJECT ""
   fi

   # Start cleaning up remaining resources in the project that CP4AIOps created 
   # and are not automatically deleted when CR is deleted
   log $INFO "Deleting kafkatopics in $CP4WAIOPS_PROJECT"
   for KAFKATOPICLABEL in ${CP4AIOPS_KAFKATOPICS_LABELS[@]}; do
      log $INFO "Deleting kafkatopic with label $KAFKATOPICLABEL..."
      oc delete kafkatopic -l $KAFKATOPICLABEL -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   log $INFO "Deleting KafkaUser in $CP4WAIOPS_PROJECT"
   oc delete kafkauser cp4waiops-cartridge-kafka-auth-0 -n $CP4WAIOPS_PROJECT --ignore-not-found

   log $INFO "Deleting lease in $CP4WAIOPS_PROJECT"
   for LEASE in ${CP4AIOPS_LEASE[@]}; do
      log $INFO "Deleting lease $LEASE.."
      oc delete $LEASE -n $CP4WAIOPS_PROJECT --ignore-not-found
   done
   
   log $INFO "Deleting internal configmaps in $CP4WAIOPS_PROJECT"
   for CONFIGMAP in ${CP4AIOPS_CONFIGMAPS_INTERNAL[@]}; do
       log $INFO "Deleting configmap $CONFIGMAP.."
       oc delete $CONFIGMAP -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   # Check for finalizer on & remove aiops-custom-size-profile configmap, if it exists
   if [ `oc get configmap aiops-custom-size-profile | grep aiops-custom-size-profile | wc -l` -gt 0 ]; then
      oc patch configmap aiops-custom-size-profile -n $CP4WAIOPS_PROJECT --type merge -p '{"metadata":{"finalizers": [null]}}'
      oc delete configmap aiops-custom-size-profile -n $CP4WAIOPS_PROJECT
   fi

   delete_EDB_related_resources
   delete_redis_resources  
   
   # Confirm with user we want to delete PVCs
   if [[ $DELETE_PVCS == "true" ]]; then
      log $INFO "Deleting Internal PVCs in $CP4WAIOPS_PROJECT"
      for PVC in ${CP4AIOPS_INTERNAL_PVC[@]}; do
         log $INFO "Deleting PVCs with label $PVC.."
         oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting PVCs in $CP4WAIOPS_PROJECT"
      for PVC in ${CP4AIOPS_PVC_LABEL[@]}; do
         log $INFO "Deleting PVCs with label $PVC.."
         oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      oc delete pvc cp4waiops-eventprocessor-eve-29ee-ep-state -n $CP4WAIOPS_PROJECT --ignore-not-found=true
      
      log $INFO "Deleting Linked secrets in $CP4WAIOPS_PROJECT"
      for LINKED_SECRET in ${CP4AIOPS_LINKED_SECRETS[@]}; do
         log $INFO "Deleting Linked secrets to some PVC's with name $LINKED_SECRET.."
         oc delete $LINKED_SECRET -n $CP4WAIOPS_PROJECT --ignore-not-found
      done      
   fi
	
   # Delete these secrets always without user's consent
   for SECRET in ${CP4AIOPS_INTERNAL_SECRETS[@]}; do
      log $INFO "Deleting internal secret  $SECRET.."
      oc delete $SECRET -n $CP4WAIOPS_PROJECT --ignore-not-found
   done 
   
   # Delete these secrets always without user's consent
   for SECRETLABEL in ${CP4AIOPS_INTERNAL_SECRETS_LABELS[@]}; do
      log $INFO "Deleting internal secret with label $SECRETLABEL.."
      oc delete secret -l $SECRETLABEL -n $CP4WAIOPS_PROJECT --ignore-not-found
   done   

   # Always delete AIOps internal ServiceAccounts
   log $INFO "Deleting the serviceaccounts in $CP4WAIOPS_PROJECT"
   for SERVICEACCOUNT in ${CP4AIOPS_INTERNAL_SERVICEACCOUNTS[@]}; do
      log $INFO "Deleting serviceaccounts $SERVICEACCOUNT.."
      oc delete $SERVICEACCOUNT -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   # Only delete shared ServiceAccounts if IA is not installed with AIOps
   if ! iaEnabled; then
      for SERVICEACCOUNT in ${CP4AIOPS_SHARED_SERVICEACCOUNTS[@]}; do
         log $INFO "Deleting serviceaccounts $SERVICEACCOUNT.."
         oc delete $SERVICEACCOUNT -n $CP4WAIOPS_PROJECT --ignore-not-found
      done
   fi
   
   # Delete Bedrock
   check_namespaced_bedrock
   if [[ "$?" == "0" ]]; then
      delete_bedrock
   fi

   delete_cert_manager_resources

   oc delete lease 2a3e2c5f.ibm.com -n $CP4WAIOPS_PROJECT
   oc delete lease a74c7b27.orchestrator.aiops.ibm.com -n $CP4WAIOPS_PROJECT

   # Remove this once official workaround is delivered from OpenSearch side
   removingLeftoverOS_workaround

   # Clean up OLM unbundling jobs/configmaps
   cleanup_bundle_unpack_jobs

   # If user configured to delete crds, then delete the dependent CRDs.
   if [[ $DELETE_CRDS == "true" ]]; then
      # Then delete the CP4AIOps CRDs
      checkForLeftOverCustomResources "${CP4AIOPS_CRDS[@]}" "CP4AIOPS"
      log $INFO "Deleting the CP4AIOps Internal CRDs..."
      delete_crd_group "CP4AIOPS_CRDS"

      checkForLeftOverCustomResources "${CP4AIOPS_DEPENDENT_CRDS[@]}" "CP4AIOPS Dependent"   
      log $INFO "Deleting the CP4AIops Dependent CRDs..."
      delete_crd_group "CP4AIOPS_DEPENDENT_CRDS"
   else
      log $INFO "Skipping delete of Dependent CRDs based on configuration in uninstall-cp4waiops.props"
   fi

   # Delete all asm instances in install namespace
   for cr in ${ASM_CRDS[@]}; do
      oc delete $cr --all -n $CP4WAIOPS_PROJECT
   done

   # Check if asm instances exist outside the ai mgr ns, and decide whether to delete those CRDs
   # There is an overlap with Event Mgr CRDs
   check_additional_asm_exists
   if [[ $DELETE_CRDS == "true" && $DELETE_ASM == "true" ]]; then
      # Check and see if there are leftover crs, if none --  delete crds
      checkForLeftOverCustomResources "${ASM_CRDS[@]}" "ASM"   
      log $INFO "Deleting ASM CRDs..."
      delete_crd_group ASM_CRDS
   else
      log $INFO "Skipping ASM CRD deletion because ASM CRs were found in other namespaces."
   fi
      
   # At this point we have cleaned up everything in the project
   log "[SUCCESS]" "----Congratulations! IBM Cloud Pak for AIOps has been uninstalled!----"
else
   log $ERROR "CP4WAIOPS_PROJECT not set. Please specify project and try again."
   display_help
   exit 1
fi