#
# Copyright 2020- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#
##################################################################################################
##### This is the configuration file associated with the uninstall-cp4waiops.sh script that  #####
##### can be used to uninstall Cloud Pak for Watson AIOps from your cluster.  Please review  #####
##### and update each of the properties below to indicate what you want to uninstall.        #####
##### IAF and zenservice below refer to the IBM Automation Foundation resources. They are    #####
##### shared by Cloud Paks and should only be removed if there are no other Cloud Paks in    #####
##### the project or the cluster.                                                            #####
##################################################################################################

# Set the name of project when Cloud Pak for Watson AIOps is installed.
AIOPS_PROJECT=""

# Set the name of installation CR to delete.
INSTALLATION_CR_NAME=""

#############################################################################################
##  NOTE: CAREFULLY READ AND REVIEW EACH ITEM BELOW AND SELECT WHICH RESOURCES TO CLEANUP  ##
#############################################################################################

# Delete the PVCs created by Cloud Pak for Watson AIOps.
# WARNING: CHOOSING TO DELETE PVCs CAN RESULT IN DATA LOSS. PLEASE CAREFULLY BACKUP AND REVIEW THE PVCS BEFORE CHOOSING TO DELETE THE PVCs.
DELETE_PVCS="false"

# Delete the secrets created by Cloud Pak for Watson AIOps.  Do not set this true if you are not deleting the PVCs at this time.
# Some of the secrets are needed to acsess data
DELETE_SECRETS="false"

# Delete the configmaps created by Cloud Pak for Watson AIOps.
DELETE_CONFIGMAPS="false"

# If you are not using Kong for anything else on this cluster outside the scope of Cloud Pak for Watson AIOps, you can choose to delete the CRDs created by Kong.
DELETE_KONG_CRDS="false"

# If you are not using Camel K for anything else on this cluster outside the scope of Cloud Pak for Watson AIOps, you can choose to delete the CRDs created by Kong.
DELETE_CAMELK_CRDS="false"

# If you do not have any other cloud paks installed in the project specified above, you can choose to uninstall zenservice from your project.
DELETE_ZENSERVICE="false"

# If you do not have any other cloud paks installed in the project specified above, you can choose to delete the project after uninstalling Cloud Pak for Watson AIOps.
DELETE_AIOPS_PROJECT="false"

# This will uninstall IBM Automation Foundation (IAF) from the cluster. If you do not have any other cloud paks installed in your cluster and want to completly clean up everything installed by Cloud Pak for Watson AIOps, you can set this option to true.
DELETE_IAF="false"

# USE WITH CAUTION!! Set to true if you want to delete ALL the resources in uninstall-cp4waiops-resource-groups
# Equivalent of setting all the flags above to true and will override any of the settings above
DELETE_ALL="false"
