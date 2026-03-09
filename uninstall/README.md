<!-- © Copyright IBM Corp. 2020, 2023-->

# Uninstall Cloud Pak for AIOps

The scripts provided here can be used to uninstall Cloud Pak for AIOps and delete resources created by it.

Note: For uninstall scripts v3.x, the script includes optionally uninstalling the IBM Automation Foundation (IAF).  IAF is the common layer shared by multiple Cloud Paks. IAF has been removed from CP4WAIOPS v4.1 and up.

## Deprecation Notice

**The uninstall script support has been deprecated starting from version 4.13.**

For Cloud Pak for AIOps version 4.13 and later, please refer to the [official IBM documentation](https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops) for the latest uninstall procedures and best practices.

## Prereqs
- You need to have OC CLI installed
- You have logged into your cluster using `oc login`

## Getting started

Clone this repo.
```
  git clone https://github.com/IBM/cp4waiops-samples.git
  cd uninstall/
```

## Preparing for uninstall

There are resources created by Cloud Pak for AIOps that you should review before deleting.  These include PVCs, secrets, CRDs, and config maps.  You might want to save some of these or consider not deleting them if you plan to reinstall.  You can check the `./x.y/uninstall-cp4waiops-resource-groups.sh` file for a list of resources that the script will delete.  You can update this list with resources you don't want to delete.

There are also resources that are shared by multiple Cloud Paks that Cloud Pak for AIOps might install if it was not already created by a different Cloud Pak.  You want to make sure those are not deleted if you are using other Cloud Paks on your cluster.

Once you have carefully reviewed and decided on what to delete, you can move forward to the next step and update the `./x.y/uninstall-cp4waiops-props.sh` file with your preferences.

## Configure what to uninstall
The `./x.y/uninstall-cp4waiops-props.sh` file is used to tell the uninstall script what to uninstall and cleanup.  Update the properties in this file with your preference.  An explanation for each property is provided in the file.

## Running the uninstall script
Once you have updated the `./x.y/uninstall-cp4waiops-props.sh` file, you are ready to run the script!

To run the uninstall, you can run
```
  cd x.y
  ./uninstall-cp4waiops.sh
```

You can choose to skip confirmation messages by passing in `-s`.

## Optional: Removing Custom Resource Definitions (CRDs)

After running the uninstall command, you may optionally remove the Custom Resource Definitions (CRDs) that were deployed by Cloud Pak for AIOps. This is an optional cleanup step that should only be performed if you are certain you will not be reinstalling CP4WAIOps.

**Warning:** Removing CRDs is a destructive operation. Ensure all custom resources have been properly deleted before removing the CRDs.

To remove the CRDs, run:
```
  cd uninstall
  ./remove-crds.sh
```

The script will:
1. Check for any remaining custom resources associated with CP4WAIOps CRDs
2. Exit with an error if any custom resources are still present
3. Delete all CP4WAIOps CRDs if no custom resources remain

**Note:** Only run this script after successfully completing the uninstall process and verifying that all CP4WAIOps resources have been removed.