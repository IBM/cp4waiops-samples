# Uninstall IBM Cloud Pak for Watson AIOps AI Manager version 3.2

The scripts provided here can be used to uninstall Cloud Pak for Watson AIOps and delete resources created by it.  This includes optionally uninstalling the Cloud Pak Platform, a common layer shared by Cloud Paks. Most of the Cloud Pak Platform components fall under IBM Automation Foundation (IAF) name.

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

There are resources created by IBM Cloud Pak for Watson AIOps AI Manager that you should review before deleting.  These include PVCs, secrets, CRDs, and config maps.  You might want to save some of these or consider not deleting them if you plan to reinstall.  You can check the `./3.2/uninstall-cp4waiops-resource-groups.props` file for a list of resources that the script will delete.  You can update this list with resources you don't want to delete.

There are also resources that are shared by multiple Cloud Paks that IBM Cloud Pak for Watson AIOps AI Manager might install if it was not already created by a different Cloud Pak.  You want to make sure those are not deleted if you are using other Cloud Paks on your cluster. The default value for `ONLY_CLOUDPAK` in the `uninstall-cp4waiops.props` file is `false` to prevent accidental deletion of these Cloud Pak Platform resources.

Once you have carefully reviewed and decided on what to delete, you can move forward to the next step and update the `./3.2/uninstall-cp4waiops.props` file with your preferences.

## Configure what to uninstall
The `./3.2/uninstall-cp4waiops.props` file is used to tell the uninstall script what to uninstall and clean up.  Update the properties in this file with your preference.  An explanation for each property is provided in the file. **Ensure the values of `CP4WAIOPS_PROJECT` and `INSTALLATION_NAME` correctly reflect your project (namespace) name and installation name.**

## Running the uninstall script
Once you have updated the `./3.2/uninstall-cp4waiops.props` file, you are ready to run the script!  


To run the uninstall, you can run
```
  cd 3.2
  ./uninstall-cp4waiops.sh
```

You can choose to skip confirmation messages by passing in `-s`.

