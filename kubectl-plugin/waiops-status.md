# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
- Discover the status of the various CP4WAIOps custom resource instances in your cluster


```
$ oc waiops status

NAMESPACE   NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
cp4waiops   aiops-installation   Running   Accepted   rook-cephfs    rook-cephfs              108m

KIND                         NAMESPACE   NAME    STATUS
IssueResolutionCore          cp4waiops   aiops   Ready
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   Ready

KIND               NAMESPACE   NAME    STATUS
LifecycleService   cp4waiops   aiops   LifecycleService ready

KIND     NAMESPACE   NAME              STATUS
BaseUI   cp4waiops   baseui-instance   Ready

KIND        NAMESPACE   NAME             STATUS
AIManager   cp4waiops   aimanager        Completed
AIOpsEdge   cp4waiops   aiopsedge        Configured
ASM         cp4waiops   aiops-topology   OK
```

## How to use

### Dependencies
Requires `oc` cli
Utilizes the current KUBECONFIG context

### Installing
Save `kubectl-plugin/kubectl-waiops` to a location in your path such as `/usr/local/bin/kubectl-waiops` and make the file executable. 

Verify plugin:
`oc plugin list`
> The output should include the location of the plugin such as /usr/local/bin/kubectl-waiops

### Quick start
```
git clone https://github.com/IBM/cp4waiops-samples.git
chmod +x cp4waiops-samples/kubectl-plugin/kubectl-waiops
cp cp4waiops-samples/kubectl-plugin/kubectl-waiops /usr/local/bin/kubectl-waiops

oc waiops status
```