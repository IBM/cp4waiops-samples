# Reference Scripts
This collection of scripts can be used to assist with some of the cluster configuration and dependency setup tasks that you might want to do before you install IBM Cloud Pak for AIOps. The scripts provide an automated approach for some ancillary options such as ODF storage and cluster logging, with reasonable default values and some customizations. The scripts are not a substitute for thorough planning or an understanding of the installation process and its consequences. It is important to review and modify these scripts to ensure that they are customized for your requirements, and that they adhere to your organization's policies and constraints.

---

- [installodf.sh](./installodf.sh) - This reference script can be used to quickly install ODF
- [installlokilogging.sh](./installlokilogging.sh) - This reference script can be used to install the OpenShift LokiStack for cluster logging
- [installclusterlogging.sh](./installclusterlogging.sh) - This reference script can be used to install the deprecated OpenShift Logging with Elasticsearch
