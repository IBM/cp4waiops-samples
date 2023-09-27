# IBM Cloud Pak for AIOps prerequisite checker tool

The prerequisite checker tool can be used to validate whether a Red Hat OpenShift Container Platform cluster has the required resources and prerequisites available to enable a successful installation or upgrade of IBM Cloud Pak for AIOps AIOps. This tool completes the following checks and generates an installation readiness report:

**Pre-Install Checker::**

- **OpenShift version check** : Checks whether the Red Hat OpenShift Container Platform cluster version is a fully supported Extended Update Support (EUS) version and compatible for installing IBM Cloud Pak for AIOps. OpenShift Container Platform 4.12.x is currently under full support and compatible.

- **Storage check**: Checks whether a storage class that uses a supported storage provider (Portworx, Red Hat Openshift Data Foundation (ODF), Storage Fusion or IBMC-file-gold-gid) is available on the cluster. For more information, see the IBM Documentation [Storage considerations](https://ibm.biz/storage_consideration_420).

**NOTE: If you plan to use Storage Fusion with AIOPS, please keep in mind the following OCP version dependencies**
| Storage Fusion Version     | OCP Versions supported |
| -------------------------- | ---------------------- |
| Storage Fusion v2.5        | OCP v4.10 and v4.12    |

- **Small or large profile install check**: Checks whether the cluster has enough resources (vCPU, Memory, and Nodes) for installing a small or large profile of IBM Cloud Pak for AIOps. For more information, see the IBM Documentation [Hardware requirements](https://ibm.biz/aiops_hardware_420).

- **Entitlement Secret check**: Checks whether a secret called ibm-entitlement-key or a global pull secret called pull-secret (global pull secret found in openshift-config namespace) have been created. For more information, see the IBM Documentation [Entitlement Keys](https://ibm.biz/entitlement_keys_420)

## Getting started

Clone the following GitHub repository:

```
  git clone https://github.com/IBM/cp4waiops-samples
  cd cp4waiops-samples/prereq-checker/4.2
```

## Running the prerequisite & upgrade checker tool script

**IMPORTANT:** Before you run the script make sure that you are in the namespace where you have installed or are planning to install IBM Cloud Pak for AIOps.
```
oc project <namespace_name>
ex: oc project cp4waiops
```

To run the prerequisite checker tool, run the following command:
```
  ./prereq.sh
```
