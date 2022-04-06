# Uninstall Cloud Pak for Watson AIOps AI Manager

The scripts provided here can be used to uninstall Cloud Pak for Watson AIOps AI Manager and delete resources created by it.  This does not uninstall Event Manager. These scripts also provide utilities to uninstall the Cloud Pak Platform (IAF and Common Services components).

## Prereqs
- You need to have OC CLI installed
- You have logged into your cluster using `oc login`

## Getting started

Clone this repo.
```
  git clone https://github.com/IBM/cp4waiops-samples.git 
  cd uninstall/3.x
```

## Preparing for uninstall

There are resources created by Cloud Pak for Watson AIOps AI Manager that you should review before deleting.  These include PVCs, secrets, CRDs, and config maps.  You might want to save some of these or consider not deleting them if you plan to reinstall.  You can check the `./3.x/uninstall-cp4waiops-resource-groups.props` file for a list of resources that the script will delete.  You can update this list with resources you don't want to delete.

There are also resources that are shared by multiple Cloud Paks that Cloud Pak for Watson AIOps AI Manager might install if it was not already created by a different Cloud Pak.  You want to make sure those are not deleted if you are using other Cloud Paks on your cluster.

Once you have carefully reviewed and decided on what to delete, you can move forward to the next step and update the `./3.x/uninstall-cp4waiops.props` file with your preferences.

## Configure what to uninstall
The `./3.x/uninstall-cp4waiops.props` file is used to tell the uninstall script what to uninstall and cleanup.  Update the properties in this file with your preference.  An explanation for each property is provided in the file. By default, the `ONLY_CLOUDPAK` toggle is set to `false` and the Cloud Pak Platform will not be removed, to protect the components other Cloud Paks may be using. 

## Running the uninstall script
Once you have updated the `./3.x/uninstall-cp4waiops.props` file, you are ready to run the script!  

To run the uninstall, you can run
```
  cd 3.x
  ./uninstall-cp4waiops.sh
```

You can choose to skip confirmation messages by passing in `-s`.
