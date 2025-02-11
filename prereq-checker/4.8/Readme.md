# IBM Cloud Pak for AIOps prerequisite checker tool

The prerequisite checker tool can be used to validate whether a Red Hat OpenShift Container Platform cluster has the required resources and prerequisites available to enable a successful installation of IBM Cloud Pak for AIOps. This tool completes the following checks and generates an installation readiness report:

**Pre-Install Checker::**

- **Platform version check** : Checks whether the platform cluster version is supported for IBM Cloud Pak for AIOps. If using a non-OCP cluster, the tool will verify if the Kubernetes Server version is greater or equal to 1.27. The following OCP versions are compatible with 4.8.1:
  - v4.14 (homogenous cluster only)
  - v4.15 (homogenous cluster only)
  - v4.16 (homogenous cluster only and Minimum 4.16.4)
  - v4.17 (homogenous cluster only)


- **Storage check**: Checks whether a storage class that uses a supported storage provider (Portworx, Red Hat Openshift Data Foundation (ODF), Storage Fusion or IBMC-file-gold-gid) is available on the cluster. For more information, see the IBM Documentation [Storage considerations](https://ibm.biz/storage_consideration_481).

**NOTE: If you plan to use Storage Fusion with AIOPS, please keep in mind the following OCP version dependencies**
| Storage Fusion Version     | OCP Versions supported          |
| -------------------------- | ------------------------------- |
| Storage Fusion v2.8.0      | 4.12, 4.13, 4.14, 4.15          |
| Storage Fusion v2.8.1      | 4.12, 4.13, 4.14, 4.15, 4.16    |



- **Starter (Non-HA) / Production (HA) install check**: Checks whether the cluster has enough resources (vCPU, Memory, and Nodes) for installing a starter or production profile of IBM Cloud Pak for AIOps. For more information, see the IBM Documentation [Hardware requirements](https://ibm.biz/aiops_hardware_481).

Note: Only nodes that have x86_64 (amd64) will only be calculated.

- **Cert Manager Operator Check**: Ensures a Cert Manager Operator is installed

- **License Service Operator Check**: Ensures the IBM Licensing operator is installed

- **Multizone Resource Check**: When the `-m` option is enabled, this will verify if zones meet the proper hardware requirements

## Getting started

Clone the following GitHub repository:

```
  git clone https://github.com/IBM/cp4waiops-samples
  cd cp4waiops-samples/prereq-checker/4.8
```

## Running the prerequisite tool script

To run the prerequisite checker tool, run the following command with the -n option and pass in the namespace/project you would like to use for CP4AIOPS:
```
  ./prereq.sh -n <namespace>
```

For help, run:
```
./prereq.sh -h
```
