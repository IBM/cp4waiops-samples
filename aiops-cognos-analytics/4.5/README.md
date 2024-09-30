# Embedded Cognos Analytics

- Execute the steps in the Ansible playbook section below to deploy Db2 & CA

## Ansible Playbook

This Ansible playbook will deploy IBM Cognos Analytics into the same namespace as IBM Cloud Pak for AIOps.
Clone the repository, and install the prerequisites.

The playbook execution will create subscriptions to operators and define custom resource instances for the workload configurations.


```sh
#  Prereqs:
# - Python / pip 3.11+
# - Ansible 2.15+ - https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
# - Logged in with oc/kubectl to an active/accessible Openshift Cluster; it will use the local kubeconfig to perform the actions
# - Authentication for cp.icr.io in global pull secret
# - For more detailed information on system requirements & prereqs, please visit https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/4.5.0?topic=analytics-installing-cognos
# - Download the ibm.mas_devops collection - for use to install DB2
ansible-galaxy collection install ibm.mas_devops

# Configure the variables in vars.yml - Storage, Namespace
# Review the product license; it is accepted by running the playbook
# - https://ibm.biz/cp4aiops-450-license
# Execute playbook - variables defined in vars.yml, license accepted at command execution
ansible-playbook aiops-cognos-playbook.yaml --extra-vars='{licenseaccept: true}'
```

### Playbook Output
The plabyook will display the process as it progresses. After it provisions and instance of IBM Cognos Analytics, it will print out the web URL. 

You can also get the web URL from the custom resource:
`oc get caserviceinstance -o yaml`

## Resources of Importance
- AIOps `Installation`: This resource is required to be deployed and in a ready state.
- `ZenService`: APIs from this workload are used to provison Cognos Analytics and configure authentication.
- `CAService`: This is the first custom resource created to start the Cognos Analytics deployment.
- `CAServiceInstance`: This is the individual service instance for IBM Cognos Analytics which gets provisioned through Zen once `CAService` workload is in place.
