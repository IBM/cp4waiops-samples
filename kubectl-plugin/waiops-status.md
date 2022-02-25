# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights

```
$ oc waiops status

NAMESPACE   NAME        PHASE     LICENSE    STORAGECLASS                STORAGECLASSLARGEBLOCK        AGE
aiops       ibm-aiops   Running   Accepted   ocs-storagecluster-cephfs   ocs-storagecluster-ceph-rbd   125m

KIND                         NAMESPACE   NAME    STATUS
IssueResolutionCore          aiops       aiops   Ready
AIOpsAnalyticsOrchestrator   aiops       aiops   Ready

KIND               NAMESPACE   NAME    STATUS
LifecycleService   aiops       aiops   Ready

KIND     NAMESPACE   NAME              STATUS
BaseUI   aiops       baseui-instance   Ready

KIND        NAMESPACE   NAME             STATUS
AIManager   aiops       aimanager        Completed
AIOpsEdge   aiops       aiopsedge        Configured
ASM         aiops       aiops-topology   OK

KIND                    NAMESPACE   NAME                    STATUS
AutomationUIConfig      aiops       iaf-system              True
AutomationBase          aiops       automationbase-sample   True
Cartridge               aiops       cp4waiops-cartridge     True
CartridgeRequirements   aiops       cp4waiops-cartridge     True

KIND         NAME                 NAMESPACE   READY       PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   aiops       Completed   100%       The Current Operation Is Completed

KIND         NAME                               NAMESPACE   READY
KafkaClaim   cp4waiops-cartridge-kafka-auth-0   aiops       True
KafkaClaim   iaf-system                         aiops       True
Kafka        iaf-system                         aiops       True
KafkaUser    aiops-ir-lifecycle-manager         aiops       True
KafkaUser    cp4waiops-cartridge-kafka-auth-0   aiops       True

KIND             NAME                                     READY
KafkaComposite   cp4waiops-cartridge-kafka-auth-0-9qqvs   True
KafkaComposite   iaf-system-xcjk5                         True

```

## How to use

### Dependencies
- `oc` cli

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
