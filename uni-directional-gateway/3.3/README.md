# Configure the uni-directional gateway for connecting with on-premises probes

This directory contains a package for setting up a uni-directional gateway between IBM Cloud Pak for Watson AIOps Event Manager and existing on-premises probes. With this gateway events can be sent from these probes to IBM Cloud Pak for Watson AIOps to become alerts.

## Getting started

Clone the following GitHub repository:

```
  git clone https://github.com:IBM/cp4waiops-samples.git
  cd uni-directional-gateway/3.3
```

Copy the package to the `$NCHOME/omnibus/gates` directory within your IBM Cloud Pak for Watson AIOps Event Manager environment. The default location for `$NCHOME` is `/opt/IBM/tivoli/netcool/`.

## Instruction documentation

For more information, and the instructions for using this package to set up the gateway, see the IBM Documentation [Connecting with on-premises probes and uni-directional gateway](https://ibm.biz/aiops_unidirectgate).
