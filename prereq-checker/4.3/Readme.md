# IBM Cloud Pak for AIOps prerequisite checker tool

The prerequisite checker tool can be used to validate whether a Red Hat OpenShift Container Platform cluster has the required resources and prerequisites available to enable a successful installation of IBM Cloud Pak for AIOps. This tool completes the following checks and generates an installation readiness report:

**Pre-Install Checker::**

- **OpenShift version check** : Checks whether the Red Hat OpenShift Container Platform cluster version is supported for IBM Cloud Pak for AIOps. The following OCP versions are compatible with 4.3.0:
  - v4.11 (non-FIPS enabled cluster only)
  - v4.12
  - v4.13
  - v4.14 (homogenous cluster only)

- **Storage check**: Checks whether a storage class that uses a supported storage provider (Portworx, Red Hat Openshift Data Foundation (ODF), Storage Fusion or IBMC-file-gold-gid) is available on the cluster. For more information, see the IBM Documentation [Storage considerations](https://ibm.biz/storage_consideration_430).

**NOTE: If you plan to use Storage Fusion with AIOPS, please keep in mind the following OCP version dependencies**
| Storage Fusion Version     | OCP Versions supported |
| -------------------------- | ---------------------- |
| Storage Fusion v2.5        | OCP v4.12              |
| Storage Fusion v2.6        | OCP v4.12              |

- **Small or large profile install check**: Checks whether the cluster has enough resources (vCPU, Memory, and Nodes) for installing a small or large profile of IBM Cloud Pak for AIOps. For more information, see the IBM Documentation [Hardware requirements](https://ibm.biz/aiops_hardware_430).

Note: Only nodes that have AMD64 will only be calculated.

- **Entitlement Secret check**: Checks whether a secret called ibm-entitlement-key or a global pull secret called pull-secret (global pull secret found in openshift-config namespace) have been created. For more information, see the IBM Documentation [Entitlement Keys](https://ibm.biz/storage_consideration_430)

## Getting started

Clone the following GitHub repository:

```
  git clone https://github.com/IBM/cp4waiops-samples
  cd cp4waiops-samples/prereq-checker/4.3
```

## Running the prerequisite checker tool script

**IMPORTANT:** Before you run the script make sure that you are in the namespace where you have installed or are planning to install IBM Cloud Pak for AIOps.
```
oc project <namespace_name>
ex: oc project cp4aiops
```

To run the prerequisite checker tool, run the following command:
```
  ./prereq.sh
```
