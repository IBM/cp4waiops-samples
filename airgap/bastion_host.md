This document walk through the highlight of commands you need to run through to do an installation of CP4WAIOps in an airgapped env using the bastion host model.
For full details on the installtion procedure, please review and follow the documention located at https://www.ibm.com/docs/en/cloud-paks/cloud-pak-watson-aiops/3.3.0?topic=installation-installing-online-offline.

### Update the values of the following env vars and run them in a terminal connected to your bastion host
#### Local registry where the images will be mirrored and run the commands
export LOCAL_DOCKER_REGISTRY_HOST=

export LOCAL_DOCKER_REGISTRY_PORT=

export LOCAL_DOCKER_REGISTRY_USER=

export LOCAL_DOCKER_REGISTRY_PASSWORD=

#### Your IBM entitlement key
export IBM_ENTITLEMENT_KEY=

#### Namespace or project on your cluster where you would like to install the product
export NAMESPACE=

#### Version of the product you would like to install.  For example, 1.2.2 maps to v3.3.2 of the product
export CASE_VERSION=1.2.2

#### Path on your bastion host of where you would like to the SAVE the CASE files
export OFFLINEDIR=$HOME/cp4waiops-aimgr/offline

#### Run the following as is
export CASE_INVENTORY_SETUP=cpwaiopsSetup

export CASE_NAME=ibm-cp-waiops

export CASE_ARCHIVE=$CASE_NAME-$CASE_VERSION.tgz

export CASE_REPO_PATH=https://github.com/IBM/cloud-pak/raw/master/repo/case

export CASE_LOCAL_PATH=$OFFLINEDIR/$CASE_ARCHIVE

export LOCAL_DOCKER_REGISTRY=$LOCAL_DOCKER_REGISTRY_HOST:$LOCAL_DOCKER_REGISTRY_PORT

export CATALOG_NAMESPACE=openshift-marketplace
`
### Login to your registry
`podman login $LOCAL_DOCKER_REGISTRY -u $LOCAL_DOCKER_REGISTRY_USER -p $LOCAL_DOCKER_REGISTRY_PASSWORD --tls-verify=false`

### Run the CASE action to save the CASE on the bastion host
`cloudctl case save --repo $CASE_REPO_PATH --case $CASE_NAME --version $CASE_VERSION --outputdir $OFFLINEDIR`

### Run the CASE actions to setup credentials
`cloudctl case launch   --case $OFFLINEDIR/$CASE_ARCHIVE   --inventory $CASE_INVENTORY_SETUP   --action configure-creds-airgap   --args "--registry cp.icr.io --user cp --pass $IBM_ENTITLEMENT_KEY"`
`cloudctl case launch    --case $OFFLINEDIR/$CASE_ARCHIVE    --inventory $CASE_INVENTORY_SETUP    --action configure-creds-airgap    --args "--registry $LOCAL_DOCKER_REGISTRY --user $LOCAL_DOCKER_REGISTRY_USER --pass $LOCAL_DOCKER_REGISTRY_PASSWORD"`

### Run the CASE action to mirror images
`cloudctl case launch   --case $CASE_LOCAL_PATH   --inventory $CASE_INVENTORY_SETUP   --action mirror-images   --args "--registry $LOCAL_DOCKER_REGISTRY --inputDir $OFFLINEDIR"`

### Run the CASE action to configure the global pull secret and imagecontentsourcepolicy
`cloudctl case launch   --case $OFFLINEDIR/$CASE_ARCHIVE   --inventory $CASE_INVENTORY_SETUP   --action configure-cluster-airgap   --namespace $NAMESPACE   --args "--registry $LOCAL_DOCKER_REGISTRY --user $LOCAL_DOCKER_REGISTRY_USER --pass $LOCAL_DOCKER_REGISTRY_PASSWORD --inputDir $OFFLINEDIR"`

### Verify the nodes have completed reloading and are all in ready state before proceeding
`oc get mcp`

### Run the CASE action to create the catalog sources
`cloudctl case launch   --case $CASE_LOCAL_PATH   --inventory $CASE_INVENTORY_SETUP   --action install-catalog   --namespace $CATALOG_NAMESPACE   --args "--registry $LOCAL_DOCKER_REGISTRY --inputDir $OFFLINEDIR"`
