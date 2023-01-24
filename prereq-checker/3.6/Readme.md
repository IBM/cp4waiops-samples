# IBM Cloud Pak for Watson AIOps AI Manager prerequisite checker tool

The prerequisite checker tool can be used to validate whether a Red Hat OpenShift Container Platform cluster has the required resources and prerequisites available to enable a successful installation or upgrade of IBM Cloud Pak for Watson AIOps AI Manager. This tool completes the following checks and generates an installation readiness report:

**Pre-Install Checker::**

- **OpenShift version check** : Checks whether the Red Hat OpenShift Container Platform cluster version is a fully supported Extended Update Support (EUS) version and compatible for installing IBM Cloud Pak for Watson AIOps AI Manager. OpenShift Container Platform 4.8.43+ and 4.10.46+ are currently under full support and compatible.

- **Storage check**: Checks whether a storage class that uses a supported storage provider (Portworx, Red Hat Openshift Data Foundation (ODF), IBM Spectrum Fusion / Spectrum Scale Container Native, or IBMC-file-gold-gid) is available on the cluster. For more information, see the IBM Documentation [Storage considerations](https://ibm.biz/storage_consideration_360).

- **Network policy check**: Checks whether the network policy is configured for the AI Manager routes, which allow external traffic to reach the routes. For more information about how the network policy is configured, see the IBM Documentation [Configure network policies](https://ibm.biz/aiops_netpolicy_360).

- **Small or large profile install check**: Checks whether the cluster has enough resources (vCPU, Memory, and Nodes) for installing a small or large profile of IBM Cloud Pak for Watson AIOps AI Manager. For more information, see the IBM Documentation [Hardware requirements](https://ibm.biz/aiops_hardware_360).

- **Entitlement Secret check**: Checks whether a secret called ibm-entitlement-key or a global pull secret called pull-secret (global pull secret found in openshift-config namespace) have been created. For more information, see the IBM Documentation [Entitlement Keys](https://ibm.biz/entitlement_keys_360)

## Getting started

Clone the following GitHub repository:

```
  git clone https://github.com/IBM/cp4waiops-samples
  cd cp4waiops-samples/prereq-checker/3.6
```

## Running the prerequisite & upgrade checker tool script

**IMPORTANT:** Before you run the script make sure that you are in the namespace where you have installed or are planning to install IBM Cloud Pak for Watson AIOps AI Manager.
```
oc project <namespace_name>
ex: oc project cp4waiops
```

To run the prerequisite checker tool, run the following command:
```
  ./prereq.sh
```

To run the upgrade checker tool, run the following command:
```
  ./prereq.sh -u
```

To run the upgrade checker tool and install upgrade requirements, if needed, run the following command:
```
  ./prereq.sh -s
```
