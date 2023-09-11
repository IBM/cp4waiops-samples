<!-- © Copyright IBM Corp. 2020, 2023-->
# Resolve "red status" issue in AIOps connections after upgrading from AIOPs 3.x to 4.x

If one or more connectors are showing a red status icon in the Connections UI after upgrading from AIOps v3.x to v4.x, it could be caused by a problem when the operator failed to update a resource in the cluster. The issue could occur in metrics connectors or Netcool/OMNIbus connector because they use a persistent storage and starting from AIOps 4.1, the access mode has been updated to `ReadWriteOnce` from `ReadWriteMany`.

An example event that indicates the deployment update failed is shown below:

```sh
$ oc describe gitapp c18fce82-2a7b-45f2-8d36-d34417576fe7 

<output omitted...>
Events:
  Type     Reason           Age                     From    Message
  ----     ------           ----                    ----    -------
  Warning  ReconcileError   145m (x15005 over 29h)  GitApp  Deployables: failed to apply connector deployment yaml to cluster: StatefulSet.apps "ibm-dyna-conn-9c02b6f2-6e37-4646-bee3-bafef95d9c2d" is invalid: spec: Forbidden: updates to statefulset spec for fields other than 'replicas', 'template', 'updateStrategy', 'persistentVolumeClaimRetentionPolicy' and 'minReadySeconds' are forbidden
```

## Running the script on all connections

1. Login to the Openshift cluster with administrator privilage.
2. (Optional) Check for any `GitApp` resources that may be stuck in `Retrying` phase.
    ```sh
    oc get gitapp
    ```
3. Run the script with `--all` to attempt the fix on all problematic connections.
   ```sh
   recreate-connector-storage.sh --namespace <AIOps namespace> --all
   ```
4. All connector `GitApp` resource status should now be `Configured`.

## Running the script on a single connection

To run the script on a single connection:

1. Get the connection name and note the resource name
   ```sh
   oc get connectorconfiguration --namespace <AIOps namespace>
   ```
2. Run the script with `--all` to attempt the fix on all problematic connections.
   ```sh
   recreate-connector-storage.sh --namespace <AIOps namespace> --connection <connectionconfiguration name>
   ```
3. All connector `GitApp` resource status should now be `Configured`.

