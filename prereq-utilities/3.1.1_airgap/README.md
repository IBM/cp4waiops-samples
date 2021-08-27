# Install Strimzi version 0.19.0 pre-requisite for Watson AIOps in airgap cluster Bastion mode

This script can be used to install Strimzi version 0.19.0 as a pre-requisite for installing Watson AIOps in airgap cluster

## Pre-requisite

* Podman
* Skopeo
* Wget

## Steps

1. Make sure you have set these environment variables for the local docker registry where all the strimzi images will be mirrored by the script.

```
export LOCAL_DOCKER_REGISTRY_HOST=<IP_or_FQDN_of_local_docker_registry>
export LOCAL_DOCKER_REGISTRY_PORT=443
export LOCAL_DOCKER_REGISTRY=$LOCAL_DOCKER_REGISTRY_HOST:$LOCAL_DOCKER_REGISTRY_PORT
export LOCAL_DOCKER_REGISTRY_USER=<username>
export LOCAL_DOCKER_REGISTRY_PASSWORD=<password>
```

2. Export the namespace where Strimzi operator will be installed

```
export NAMESPACE=openshift-operators
```

3. Execute the script to install the Strimzi operator

```
./scripts/install_strimzi_0_19_0.sh
```

4. Verify that the Strimzi operator is running.

Run the following command on your air-gap cluster, and verify that 'strimzi-cluster-operator-xxx' is returned.

```
oc get pods -n openshift-operators
```

Example output:

```
oc get pods -n openshift-operators
NAME                                        READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-69658cf889-xmnrm   1/1     Running   0          5m31s
```