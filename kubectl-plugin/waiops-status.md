# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights

### Main status checker
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

KIND                    NAMESPACE   NAME                    STATUS
AutomationUIConfig      cp4waiops   iaf-system              True
AutomationBase          cp4waiops   automationbase-sample   True
Cartridge               cp4waiops   cp4waiops-cartridge     True
CartridgeRequirements   cp4waiops   cp4waiops-cartridge     True

KIND         NAME                 NAMESPACE   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4waiops   Completed   100%       The Current Operation Is Completed
```

### Status checker for upgrade scenario:
```
$ oc waiops upgrade-status

Enter your Cloud Pak for Watson AIOps installation namespace: katamari

______________________________________________________________

The following component(s) have finished upgrading:


KIND        NAMESPACE   NAME        STATUS
AIOpsEdge   katamari    aiopsedge   Configured

KIND   NAMESPACE   NAME
Kong   katamari    gateway

KIND        NAMESPACE   NAME        VERSION   STATUS
AIManager   katamari    aimanager   2.4.0     Completed

KIND                         NAMESPACE   NAME    VERSION   STATUS
AIOpsAnalyticsOrchestrator   katamari    aiops   3.2.0     Ready

______________________________________________________________

______________________________________________________________

Meanwhile, the following component(s) have not upgraded yet:


KIND               NAMESPACE   NAME    VERSION   STATUS
LifecycleService   katamari    aiops   3.2.0     Ready

KIND                  NAMESPACE   NAME    VERSION   STATUS
IssueResolutionCore   katamari    aiops   3.2.0     Ready

If only a short time has passed since the upgrade was started, the components may
need more time to complete upgrading. If you have waited a significant amount of time
and the statuses of the components listed above are not changing, please refer to
the troubleshooting docs or open a support case.

______________________________________________________________

Hint: for a more detailed printout of each operator's components' statuses, run `oc waiops status`.
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
oc waiops upgrade-status
```
