# Installing Watson AIOps AI-Manager 3.2.1 on ROKS

Here are the steps to install IBM Watson AIOps AI Manager 3.2.1 on ROKS by using scripts.

## 1. Update Config file

1. Get `IBM entitlement key` from https://myibm.ibm.com/products-services/containerlibrary

2. Replace the value of the `ENTITLEMENT_KEY` variable in `files/00-config.sh`.

```
#!/bin/bash

## Entitlement key
export ENTITLEMENT_KEY=ABCD

## Namespace where WAIOps to be isnstalled.
export NAMESPACE=cp4waiops
```

## 2. Login into OpenShift

Login into OpenShift cluster where you want to install AI-Manager.

```
oc login ......
```

## 3. Run the install script

Goto the files folder and run the installation script as givenelow.

```
cd files
sh 10-install-ai-manager.sh
```

- It would take around 1hr to complete the istallation. 
- By default the installation is done on the namespace `cp4waiops`
- Keep checking the logs for the status. 
- The same script can be run again and again if the install stopped for any reason.

## 4. Output
 
The installation would be completed and the output could be like this.

```
=====================================================================================================
URL : https://cpd-cp4waiops.aaaaaaaa.ams03.containers.appdomain.cloud
USER: admin
PASSWORD: 
=====================================================================================================

```
You can use this to login into the WAIOps Console.



## Reference

https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.2.1?topic=manager-starter-installation
