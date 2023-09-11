<!-- © Copyright IBM Corp. 2021 -->

# Install Strimzi for an IBM Cloud Pak Watson AIOps air-gapped installation that uses a Bastion host

This script can be used to install Strimzi version 0.19.0 as a prerequisite for installing IBM Cloud Pak Watson AIOps in an air-gapped environment.

## Prerequisites

* Podman
* Skopeo
* Wget

## Procedure

1. Ensure that you set the following environment variables for the local docker registry that you will use with the script to mirror the Strimzi images.
```
export LOCAL_DOCKER_REGISTRY_HOST=<IP_or_FQDN_of_local_docker_registry>
export LOCAL_DOCKER_REGISTRY_PORT=443
export LOCAL_DOCKER_REGISTRY=$LOCAL_DOCKER_REGISTRY_HOST:$LOCAL_DOCKER_REGISTRY_PORT
export LOCAL_DOCKER_REGISTRY_USER=<username>
export LOCAL_DOCKER_REGISTRY_PASSWORD=<password>
```

2. Export the namespace where you will be installing the Strimzi operator.

```
export NAMESPACE=openshift-operators
```

3. Execute the script to install the Strimzi operator.

```
./scripts/install_strimzi_0_19_0.sh
```

4. Verify that the Strimzi operator is running.

Run the following command on your air-gapped cluster. Verify that 'strimzi-cluster-operator-xxx' is returned.

```
oc get pods -n openshift-operators
```

Example output:

```
oc get pods -n openshift-operators
NAME                                        READY   STATUS    RESTARTS   AGE
strimzi-cluster-operator-69658cf889-xmnrm   1/1     Running   0          5m31s
```