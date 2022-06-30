
## Uninstall Secure Tunnel as a standalone installation and uninstall Tunnel connector
This script provided here can be used to uninstall Secure Tunnel as a standalone installation and can also be used to uninstall the Tunnel connector.

## Prereqs
- You need to have OC or kubectl CLI installed
- You have logged into your cluster using oc login or kubectl config.

## Getting started
Clone this repo.
```
  git clone https://github.com/IBM/cp4waiops-samples.git 
  cd uninstall/3.x/secure-tunnel
```

## Running the uninstall script
- To run `uninstall-securetunnel-standalone.sh --namespace <the namespace of the secure tunnel server>` to uninstall Secure Tunnel as a standalone installation.
- To run `uninstall-securetunnel-standalone.sh --type connector  --namespace <the namespace of the tunnel connector> --connection-name <the tunnel connection name that you created from the Tunnel console UI>` to uninstall the Tunnel connector from a cluster.
- To run `uninstall-securetunnel-standalone.sh --type connector --connection-name <the tunnel connection name that you created from the Tunnel console UI>` to uninstall the Tunnel connector from a Host machine(VM or physical machine).
