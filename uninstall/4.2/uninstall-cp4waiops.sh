#!/bin/bash
#
# © Copyright IBM Corp. 2020, 2023
# SPDX-License-Identifier: Apache2.0
#
# This script can be used to uninstall the IBM Cloud Pak for AIOps v4.2 product and
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
  log $INFO "\033[0;33mUninstall v1.0 for AIOPs v4.2\033[0m"
  log $INFO
  log $INFO "This script will uninstall IBM Cloud Pak for AIOps version 4.2. Please ensure you have deleted any CRs you created before running this script."
  log $INFO ""
  log $INFO "##### IMPORTANT ######"
  log $INFO ""
  log $INFO "Please review and update the contents of uninstall-cp4waiops.props carefully to configure what you want to delete before proceeding."
  log $INFO "CAUTION: Data loss is possible if uninstall-cp4waiops.props is not reviewed and configured carefully."
  log $INFO ""
  log $INFO "Cluster context: $(oc config current-context)"
  log $INFO ""
  display_script_properties
  read -p "Please confirm you have reviewed and configured uninstall-cp4waiops.props and would like to proceed with uninstall. Y or y to continue: " -n 1 -r
  log " "
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log $INFO "Cancelling uninstall of IBM Cloud Pak for AIOps."
    exit 0
  fi
  log " "
  if [[ $ONLY_CLOUDPAK == "true" ]]; then
    read -p "You have selected ONLY_CLOUDPAK to be true. If you have other cloud paks installed on your cluster, they will stop working if you continue. Are you sure you would like to proceed?  Y or y to continue: " -n 1 -r
    log " "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log $INFO "Cancelling uninstall of IBM Cloud Pak for AIOps."
      exit 0
    fi
  fi
else
  log $INFO "\033[0;33mUninstall v1.0 for AIOPs v4.2\033[0m"
  log $INFO
  log $INFO "This script will uninstall IBM Cloud Pak for AIOps."
  display_script_properties
  log $INFO ""
fi 

check_namespaced_install

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
   
   # Then delete the CP4WAIOps CRDs
   log $INFO "Deleting the CP4WAIOps Internal CRDs..."
   delete_crd_group "CP4WAIOPS_CRDS"

   # If user configured to delete crds, then delete the dependent CRDs.
   if [[ $DELETE_CRDS == "true" ]]; then   
      log $INFO "Deleting the CP4WAIops Dependent CRDs..."
      delete_crd_group "CP4WAIOPS_DEPENDENT_CRDS"
   else
      log $INFO "Skipping delete of Dependent CRDs based on configuration in uninstall-cp4waiops.props"
   fi
   
   log $INFO "Deleting the misc resources in $CP4WAIOPS_PROJECT "
   for RESOURCE_MISC in ${CP4WAIOPS_MISC[@]}; do
       log $INFO "Deleting resource  $RESOURCE_MISC.."
       oc delete $RESOURCE_MISC -n $CP4WAIOPS_PROJECT --ignore-not-found
   done
   delete_IRCoreResources

   # Check if asm instances exist outside the ai mgr ns, and decide whether to delete those CRDs
   # There is an overlap with Event Mgr CRDs
   check_additional_asm_exists
   if [[ $DELETE_ASM == "true" ]]; then
      log $INFO "Deleting ASM CRDs..."
      delete_crd_group ASM_CRDS
   else
      log $INFO "Skipping ASM CRD deletion."
   fi
   
   delete_securetunnel
   
   # Finally uninstall the CP4WAIOps operator by deleting the subscription & CSV
   log $INFO "Uninstalling the CP4WAIOps operator..."
   # Check if namespace scoped install. If namespaced, pass in CP4WAIOPS_PROJECT, else OPERATORS_PROJECT
   if [[ $AIOPS_NAMESPACED == "true" ]] ; then
    unsubscribe "ibm-aiops-orchestrator" $CP4WAIOPS_PROJECT ""
   else
	unsubscribe "ibm-aiops-orchestrator" $OPERATORS_PROJECT ""
   fi

   # Now verify from user input that there are no other cloud paks in this project
   # If there aren't, start deleting Zen/Bedrock
   if [[ $ONLY_CLOUDPAK == "true" ]]; then

      # Delete Crossplane Dependencies
      log $INFO "Deleting Crossplane dependencies"
      log $INFO "Delete the operators and owned custom resources"
      delete_crossplane

    # Then delete the zenservice instance
   	log $INFO "Deleting the zenservice CR..."
   	delete_zenservice_instance $ZENSERVICE_CR_NAME $CP4WAIOPS_PROJECT

      log $INFO "Deleting MISC secrets in $CP4WAIOPS_PROJECT"
      for SECRET in ${IAF_SECRETS[@]}; do
            log $INFO "Deleting secret $SECRET.."
            oc delete $SECRET -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting MISC certs in $CP4WAIOPS_PROJECT"
      for CERT in ${IAF_CERTMANAGER[@]}; do
            log $INFO "Deleting cert $CERT.."
            oc delete $CERT -n $CP4WAIOPS_PROJECT --ignore-not-found
      done
   fi

   # Start cleaning up remaining resources in the project that CP4WAIOps created 
   # and are not automatically deleted when CR is deleted
   log $INFO "Deleting kafkatopics in $CP4WAIOPS_PROJECT"
   for KAFKATOPICLABEL in ${CP4WAIOPS_KAFKATOPICS_LABELS[@]}; do
         log $INFO "Deleting kafkatopic with label $KAFKATOPICLABEL..."
         oc delete kafkatopic -l $KAFKATOPICLABEL -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   log $INFO "Deleting lease in $CP4WAIOPS_PROJECT"
   for LEASE in ${CP4WAIOPS_LEASE[@]}; do
         log $INFO "Deleting lease $LEASE.."
         oc delete $LEASE -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   log $INFO "Deleting internal configmaps with labels in $CP4WAIOPS_PROJECT"
   for CONFIGMAP_LABEL in ${CP4WAIOPS_CONFIGMAPS_INTERNAL_LABELS[@]}; do
       log $INFO "Deleting configmap with label $CONFIGMAP_LABEL.."
       oc delete configmap -l $CONFIGMAP_LABEL -n $CP4WAIOPS_PROJECT --ignore-not-found
   done
   
   log $INFO "Deleting internal configmaps in $CP4WAIOPS_PROJECT"
   for CONFIGMAP in ${CP4WAIOPS_CONFIGMAPS_INTERNAL[@]}; do
       log $INFO "Deleting configmap $CONFIGMAP.."
       oc delete $CONFIGMAP -n $CP4WAIOPS_PROJECT --ignore-not-found
   done

   # Check for finalizer on & remove aiops-custom-size-profile configmap, if it exists
   if [ `oc get configmap aiops-custom-size-profile | grep aiops-custom-size-profile | wc -l` -gt 0 ]; then
      oc patch configmap aiops-custom-size-profile -n $CP4WAIOPS_PROJECT --type merge -p '{"metadata":{"finalizers": [null]}}'
      oc delete configmap aiops-custom-size-profile -n $CP4WAIOPS_PROJECT
   fi

   log $INFO "Deleting Postgres Cluster $INSTALLATION_NAME-edb-postgres in $CP4WAIOPS_PROJECT"
   oc delete cluster.postgresql.k8s.enterprisedb.io/${INSTALLATION_NAME}-edb-postgres -n $CP4WAIOPS_PROJECT

   log $INFO "Deleting FlinkCluster cp4waiops-eventprocessor-eve-29ee-ep in $CP4WAIOPS_PROJECT"
   oc delete flinkcluster cp4waiops-eventprocessor-eve-29ee-ep -n $CP4WAIOPS_PROJECT

   #Delete these PVC's always without user's consent
   log $INFO "Deleting Internal PVCs in $CP4WAIOPS_PROJECT"
   for PVC in ${CP4WAIOPS_INTERNAL_PVC[@]}; do
            log $INFO "Deleting PVCs with label $PVC.."
            oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
   done
   
   # Confirm with user we want to delete PVCs
   if [[ $DELETE_PVCS == "true" ]]; then
      log $INFO "Deleting PVCs in $CP4WAIOPS_PROJECT"
      for PVC in ${CP4WAIOPS_PVC_LABEL[@]}; do
            log $INFO "Deleting PVCs with label $PVC.."
            oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      oc delete pvc cp4waiops-eventprocessor-eve-29ee-ep-state -n $CP4WAIOPS_PROJECT --ignore-not-found=true
      
      log $INFO "Deleting Linked secrets in $CP4WAIOPS_PROJECT"
      for LINKED_SECRET in ${CP4WAIOPS_LINKED_SECRETS[@]}; do
            log $INFO "Deleting Linked secrets to some PVC's with name $LINKED_SECRET.."
            oc delete $LINKED_SECRET -n $CP4WAIOPS_PROJECT --ignore-not-found
      done
      
   fi
	
   # Delete these secrets always without user's consent
   for SECRET in ${CP4WAIOPS_INTERNAL_SECRETS[@]}; do
       log $INFO "Deleting internal secret  $SECRET.."
       oc delete $SECRET -n $CP4WAIOPS_PROJECT --ignore-not-found
   done 
   
   # Delete these secrets always without user's consent
   for SECRETLABEL in ${CP4WAIOPS_INTERNAL_SECRETS_LABELS[@]}; do
       log $INFO "Deleting internal secret with label $SECRETLABEL.."
       oc delete secret -l $SECRETLABEL -n $CP4WAIOPS_PROJECT --ignore-not-found
   done   

   
   log $INFO "Deleting the serviceaccounts in $CP4WAIOPS_PROJECT"
   for SERVICEACCOUNT in ${CP4WAIOPS_SERVICEACCOUNTS[@]}; do
       log $INFO "Deleting serviceaccounts $SERVICEACCOUNT.."
       oc delete $SERVICEACCOUNT -n $CP4WAIOPS_PROJECT --ignore-not-found
   done      


   # Remove Redis annotation from the namespace.  Leaving the annotation
   # would prevent a Redis re-install in the namespace.  Note that the
   # hyphen on the end of the annotation key is what tells oc to delete
   # the annotation rather than update it.
   oc annotate namespace $CP4WAIOPS_PROJECT redis.databases.cloud.ibm.com/account-hash-
   
   # Finally uninstall & cleanup resources created at cluster scope & other projects 
   # if user confirms they have no other cloud paks on the cluster and want to do a full uninstall
   if [[ $ONLY_CLOUDPAK == "true" ]]; then
      log $INFO "Deleting Bedrock"
      delete_iaf_bedrock

      log $INFO "Deleting MISC leases in $CP4WAIOPS_PROJECT"
      for LEASE in ${IAF_LEASES[@]}; do
         log $INFO "Deleting lease $LEASE.."
         oc delete $LEASE -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting MISC configmaps in $CP4WAIOPS_PROJECT"
      for CONFIGMAP in ${IAF_CONFIGMAPS[@]}; do
            log $INFO "Deleting configmap $CONFIGMAP.."
            oc delete $CONFIGMAP -n $CP4WAIOPS_PROJECT --ignore-not-found
      done

      log $INFO "Deleting Zen PVCs in $CP4WAIOPS_PROJECT"
      for PVC in ${ZEN_PVCS_LABELS[@]}; do
            log $INFO "Deleting PVC $PVC.."
            oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
      done
      
      if [[ $DELETE_PVCS == "true" ]]; then
         log $INFO "Deleting MISC PVCs in $CP4WAIOPS_PROJECT"
         for PVC in ${IAF_PVCS_LABELS[@]}; do
             log $INFO "Deleting PVC $PVC.."
             oc delete pvc -l $PVC -n $CP4WAIOPS_PROJECT --ignore-not-found
         done
      fi      
   fi
      
      # At this point we have cleaned up everything in the project

   log "[SUCCESS]" "----Congratulations! IBM Cloud Pak for AIOps has been uninstalled!----"
   if [[ $ONLY_CLOUDPAK == "true" ]]; then 
   # If Cloud Pak Platform was removed, or IAF was installed at the cluster scope, cp4waiops project can be deleted
      log "[SUCCESS]" "------ \033[1;36mYou can now delete the $CP4WAIOPS_PROJECT project safely.\033[0m------"
   fi
else
   log $ERROR "CP4WAIOPS_PROJECT not set. Please specify project and try again."
   display_help
   exit 1
fi
