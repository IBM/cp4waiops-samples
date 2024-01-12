<!-- © Copyright IBM Corp. 2020, 2023-->

#### ***NOTE**: from CP4AIOps v4.1.0 onwards, the use of the status, status-all, status-upgrade functions are now considered **deprecated**. Please primarily refer to the installation status messages provided directly in the installation.orchestrator.aiops.ibm.com CR instance of your cluster's installation.*

# kubectl-waiops

A kubectl plugin for CP4AIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
Run `oc waiops multizone status` to view how well the installation is prepared for a zone outage.
  * **NOTE**: This function requires bash to be at least version **4**  (MacOS ships with a very old version)
  * **NOTE**: If you have installed/upgraded bash to a path other than `/bin/bash` change the first line of the script to that fully qualified path.

Run `oc waiops status` to print the statuses of some of your instance's main components. If you see components with issues (or are generally facing issues on your cluster), run `oc waiops status-all` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status`)
```
$ oc waiops status
Cloud Pak for AIOps v4.4 installation status:
  Componentstatus:
    Aimanager:                       Ready
    Aiopsanalyticsorchestrator:      Ready
    Aiopsedge:                       Ready
    Aiopsui:                         Ready
    Asm:                             Ready
    Baseui:                          Ready
    Cluster:                         Ready
    Commonservice:                   Ready
    Elasticsearch:                   Ready
    Flinkcluster:                    Ready
    Issueresolutioncore:             Ready
    Kafka:                           Ready
    Kong:                            Ready
    Lifecycleservice:                Ready
    Tunnel:                          Ready
    Zenservice:                      Ready
  Custom Profile Configmap:          aiops-custom-size-profile
  Custom Profile Validation Status:  Custom profile configmap not found, continue installation process without customization
  Image Pull Secret:                 Global
  Licenseacceptance:                 Accepted
  Locations:
    Cloud Pak Ui URL:      <URL>
    Cs Admin Hub URL:      <URL>
  Phase:                   Running
  Size:                    small
  Storageclass:            <Your Storageclass>
  Storageclasslargeblock:  <Your Storageclasslargeblock>
```

### Detailed installation status checker output (`oc waiops status-all`)
```
$ oc waiops status-all
Cloud Pak for AIOps v4.3 installation status:
______________________________________________________________
Installation instances:

NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            141m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   katamari    4.8.10    Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   katamari    iaf-system   True

KIND            NAMESPACE   NAME         STATUS
Elasticsearch   katamari    iaf-system   True

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.3.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   3.4.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.3.0     Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   katamari    baseui-instance   4.3.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.3.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.19.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.3.0     True     Ready

______________________________________________________________
Kong instances:

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   katamari    gateway   True     <none>

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                              STATUS
Cluster   katamari    aiops-installation-edb-postgres   Cluster in healthy state

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   katamari    sre-tunnel   True

______________________________________________________________
CSVs from katamari namespace:

NAME                                     DISPLAY                VERSION              REPLACES   PHASE
aimanager-operator.v4.3.0-202311171845   IBM AIOps AI Manager   4.3.0-202311171845              Succeeded

NAME                                     DISPLAY          VERSION              REPLACES   PHASE
aiopsedge-operator.v4.3.0-202311171845   IBM AIOps Edge   4.3.0-202311171845              Succeeded

NAME                               DISPLAY                             VERSION              REPLACES   PHASE
asm-operator.v4.3.0-202311171845   IBM Netcool Agile Service Manager   4.3.0-202311171845              Succeeded

NAME                                  DISPLAY                                            VERSION              REPLACES   PHASE
ibm-aiops-ir-ai.v4.3.0-202311171845   IBM Watson AIOps Issue Resolution AI & Analytics   4.3.0-202311171845              Succeeded

NAME                                    DISPLAY                                  VERSION              REPLACES   PHASE
ibm-aiops-ir-core.v4.3.0-202311171845   IBM Watson AIOps Issue Resolution Core   4.3.0-202311171845              Succeeded

NAME                                         DISPLAY                                    VERSION              REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.3.0-202311171845   IBM Cloud Pak for Watson AIOps Lifecycle   4.3.0-202311171845              Succeeded

NAME                                         DISPLAY                   VERSION              REPLACES   PHASE
ibm-aiops-orchestrator.v4.3.0-202311171845   IBM Cloud Pak for AIOps   4.3.0-202311171845              Succeeded

NAME                             DISPLAY       VERSION   REPLACES   PHASE
ibm-automation-elastic.v1.3.14   IBM Elastic   1.3.14               Succeeded

NAME                           DISPLAY                           VERSION   REPLACES   PHASE
ibm-automation-flink.v1.3.14   IBM Automation Foundation Flink   1.3.14               Succeeded

NAME                                DISPLAY                  VERSION   REPLACES                           PHASE
ibm-cloud-databases-redis.v1.6.11   IBM Operator for Redis   1.6.11    ibm-cloud-databases-redis.v1.6.9   Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v3.23.9   IBM Cloud Pak foundational services   3.23.9               Succeeded

NAME                                      DISPLAY                         VERSION              REPLACES   PHASE
ibm-management-kong.v4.3.0-202311171845   IBM Internal - IBM AIOps Kong   4.3.0-202311171845              Succeeded

NAME                                             DISPLAY             VERSION              REPLACES   PHASE
ibm-secure-tunnel-operator.v4.3.0-202311171845   IBM Secure Tunnel   4.3.0-202311171845              Succeeded

NAME                                               DISPLAY        VERSION              REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.3.0-202311171845   IBM AIOps UI   4.3.0-202311171845              Succeeded

______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.18.6   EDB Postgres for Kubernetes   1.18.6    cloud-native-postgresql.v1.18.5   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v3.25.9   IBM Cert Manager   3.25.9               Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v3.23.9   IBM Cloud Pak foundational services   3.23.9               Succeeded

NAME                            DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v1.21.9   Ibm Common UI   1.21.9               Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v4.9.0   IBM Events Operator   4.9.0                Succeeded

NAME                       DISPLAY   VERSION   REPLACES   PHASE
ibm-iam-operator.v3.23.9   IBM IAM   3.23.9               Succeeded

NAME                                 DISPLAY                      VERSION   REPLACES   PHASE
ibm-ingress-nginx-operator.v1.20.9   IBM Ingress Nginx Operator   1.20.9               Succeeded

NAME                             DISPLAY         VERSION   REPLACES   PHASE
ibm-licensing-operator.v1.20.9   IBM Licensing   1.20.9               Succeeded

NAME                                      DISPLAY              VERSION   REPLACES   PHASE
ibm-management-ingress-operator.v1.20.9   Management Ingress   1.20.9               Succeeded

NAME                           DISPLAY                VERSION   REPLACES   PHASE
ibm-mongodb-operator.v1.18.9   IBM MongoDB Operator   1.18.9               Succeeded

NAME                                   DISPLAY                       VERSION   REPLACES   PHASE
ibm-namespace-scope-operator.v1.17.9   IBM NamespaceScope Operator   1.17.9               Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-platform-api-operator.v3.25.9   IBM Platform API   3.25.9               Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v1.8.10   IBM Zen Service   1.8.10               Succeeded

NAME                                           DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v1.21.9   Operand Deployment Lifecycle Manager   1.21.9               Succeeded

______________________________________________________________
Subscriptions from katamari namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.3

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.3

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.3

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.3

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-automation-elastic   ibm-automation-elastic   ibm-cp-waiops-catalog   v1.3

NAME                   PACKAGE                SOURCE                  CHANNEL
ibm-automation-flink   ibm-automation-flink   ibm-cp-waiops-catalog   v1.3

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-management-kong   ibm-management-kong   ibm-cp-waiops-catalog   v4.3

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.3

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.3

NAME             PACKAGE           SOURCE                  CHANNEL
ir-ai-operator   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.3

NAME               PACKAGE             SOURCE                  CHANNEL
ir-core-operator   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.3

NAME                    PACKAGE                  SOURCE                  CHANNEL
ir-lifecycle-operator   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.3

NAME    PACKAGE                              SOURCE                  CHANNEL
redis   ibm-cloud-databases-redis-operator   ibm-cp-waiops-catalog   v1.6

______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable

NAME                        PACKAGE                     SOURCE                  CHANNEL
ibm-cert-manager-operator   ibm-cert-manager-operator   ibm-cp-waiops-catalog   v3.23

NAME                          PACKAGE                       SOURCE                  CHANNEL
ibm-common-service-operator   ibm-common-service-operator   ibm-cp-waiops-catalog   v3.23

NAME                    PACKAGE                     SOURCE                  CHANNEL
ibm-commonui-operator   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v3.23

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v3

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-cp-waiops-catalog   v3.23

NAME                         PACKAGE                          SOURCE                  CHANNEL
ibm-ingress-nginx-operator   ibm-ingress-nginx-operator-app   ibm-cp-waiops-catalog   v3.23

NAME                     PACKAGE                      SOURCE                  CHANNEL
ibm-licensing-operator   ibm-licensing-operator-app   ibm-cp-waiops-catalog   v3.23

NAME                              PACKAGE                               SOURCE                  CHANNEL
ibm-management-ingress-operator   ibm-management-ingress-operator-app   ibm-cp-waiops-catalog   v3.23

NAME                   PACKAGE                    SOURCE                  CHANNEL
ibm-mongodb-operator   ibm-mongodb-operator-app   ibm-cp-waiops-catalog   v3.23

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-namespace-scope-operator   ibm-namespace-scope-operator   ibm-cp-waiops-catalog   v3.23

NAME                        PACKAGE                         SOURCE                  CHANNEL
ibm-platform-api-operator   ibm-platform-api-operator-app   ibm-cp-waiops-catalog   v3.23

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-cp-waiops-catalog   v3.23

NAME                                       PACKAGE    SOURCE                  CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-cp-waiops-catalog   v3.23

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-ai-manager   Running   2023-11-17T19:37:58Z

NAMESPACE   NAME                         PHASE     CREATED AT
katamari    ibm-aiops-aiops-foundation   Running   2023-11-17T19:37:58Z

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-connection   Running   2023-11-17T19:37:58Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-service   Running   2023-11-17T19:52:17Z

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   ibm-commonui-request   Running   2023-11-17T19:34:51Z

NAMESPACE             NAME              PHASE     CREATED AT
ibm-common-services   ibm-iam-request   Running   2023-11-17T19:34:51Z

NAMESPACE             NAME                  PHASE     CREATED AT
ibm-common-services   ibm-mongodb-request   Running   2023-11-17T19:36:37Z

NAMESPACE             NAME                 PHASE     CREATED AT
ibm-common-services   management-ingress   Running   2023-11-17T19:36:37Z

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   platform-api-request   Running   2023-11-17T19:36:38Z

______________________________________________________________
ODLM pod current status:

ibm-common-services                                operand-deployment-lifecycle-manager-865ffcc766-grkdh                     1/1     Running     0              141m
______________________________________________________________
Orchestrator pod current status:

katamari                                           ibm-aiops-orchestrator-controller-manager-64d5cfd7c4-h8mxd                1/1     Running     0              144m
```

### Upgrade status checker (`oc waiops status-upgrade`):
```
$ oc waiops status-upgrade
Cloud Pak for AIOps AI Manager v4.3 upgrade status:

______________________________________________________________

The following component(s) have finished upgrading:


KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.3.0     True     Ready

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   katamari    gateway   True     <none>

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.3.0     Completed   AI Manager is ready

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.3.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.3.0     Ready    All Services Ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.19.0    OK

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.3.0     Ready    All Services Ready

______________________________________________________________

```

## How to use

### Requirements
- You must have an installation of Cloud Pak for AIOps v3.3, v3.4, v3.5, v3.6, v3.7, v4.1, v4.2, v4.3, or v4.4 on your cluster. 

**Note**: while this tool does not require you to be logged in as a cluster admin, however
 * `oc waiops multizone status` output may be limited and inaccurate without the required permissions
 * `oc waiops status-all`'s output will be limited if you are not. If possible, it is recommended to be logged in as a cluster admin to receive a more complete view of your install status.

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

oc waiops multizone status
oc waiops status
oc waiops status-all
oc waiops status-upgrade
```
