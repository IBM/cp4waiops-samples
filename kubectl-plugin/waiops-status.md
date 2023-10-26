<!-- © Copyright IBM Corp. 2020, 2023-->

#### ***NOTE**: from CP4AIOps v4.1.0 onwards, the use of the status, status-all, status-upgrade functions are now considered **deprecated**. Please primarily refer to the installation status messages provided directly in the installation.orchestrator.aiops.ibm.com CR instance of your cluster's installation.*

# kubectl-waiops

A kubectl plugin for CP4AIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
Run `oc waiops multizone status` to view how well the installation is prepared for a zone outage.

Run `oc waiops status` to print the statuses of some of your instance's main components. If you see components with issues (or are generally facing issues on your cluster), run `oc waiops status-all` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status`)
```
$ oc waiops status
Cloud Pak for AIOps AI Manager v4.2 installation status:
______________________________________________________________
Installation instances:

NAME           PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
ibm-cp-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          77m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   katamari    4.8.8     Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   katamari    iaf-system   True

KIND            NAMESPACE   NAME         STATUS
Elasticsearch   katamari    iaf-system   True

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.2.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.2.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.2.0     Ready   All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   katamari    baseui-instance   4.2.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.2.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.17.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.2.0     True     Ready

______________________________________________________________

Hint: for a more detailed printout of component statuses, run `oc waiops status-all`.
```

### Detailed installation status checker output (`oc waiops status-all`)
```
$ oc waiops status-all
Cloud Pak for AIOps AI Manager v4.2 installation status:
______________________________________________________________
Installation instances:

NAME           PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
ibm-cp-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          78m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   katamari    4.8.8     Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   katamari    iaf-system   True

KIND            NAMESPACE   NAME         STATUS
Elasticsearch   katamari    iaf-system   True

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.2.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.2.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.2.0     Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   katamari    baseui-instance   4.2.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.2.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.17.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.2.0     True     Ready

______________________________________________________________
Kong instances:

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   katamari    gateway   True     <none>

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                        STATUS
Cluster   katamari    ibm-cp-aiops-edb-postgres   Cluster in healthy state

______________________________________________________________
CSVs from katamari namespace:

NAME                                     DISPLAY                VERSION              REPLACES   PHASE
aimanager-operator.v4.2.0-202309121245   IBM AIOps AI Manager   4.2.0-202309121245              Succeeded

NAME                                     DISPLAY          VERSION              REPLACES   PHASE
aiopsedge-operator.v4.2.0-202309121245   IBM AIOps Edge   4.2.0-202309121245              Succeeded

NAME                               DISPLAY                             VERSION              REPLACES   PHASE
asm-operator.v4.2.0-202309121245   IBM Netcool Agile Service Manager   4.2.0-202309121245              Succeeded

NAME                                  DISPLAY                                            VERSION              REPLACES   PHASE
ibm-aiops-ir-ai.v4.2.0-202309121245   IBM AIOps Issue Resolution AI & Analytics   4.2.0-202309121245              Succeeded

NAME                                    DISPLAY                                  VERSION              REPLACES   PHASE
ibm-aiops-ir-core.v4.2.0-202309121245   IBM AIOps Issue Resolution Core   4.2.0-202309121245              Succeeded

NAME                                         DISPLAY                                    VERSION              REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.2.0-202309121245   IBM Cloud Pak for AIOps Lifecycle   4.2.0-202309121245              Succeeded

NAME                                         DISPLAY                   VERSION              REPLACES   PHASE
ibm-aiops-orchestrator.v4.2.0-202309121245   IBM Cloud Pak for AIOps   4.2.0-202309121245              Succeeded

NAME                             DISPLAY       VERSION   REPLACES   PHASE
ibm-automation-elastic.v1.3.14   IBM Elastic   1.3.14               Succeeded

NAME                           DISPLAY                           VERSION   REPLACES   PHASE
ibm-automation-flink.v1.3.14   IBM Automation Foundation Flink   1.3.14               Succeeded

NAME                               DISPLAY                  VERSION   REPLACES                           PHASE
ibm-cloud-databases-redis.v1.6.9   IBM Operator for Redis   1.6.9     ibm-cloud-databases-redis.v1.6.8   Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v3.23.7   IBM Cloud Pak foundational services   3.23.7               Succeeded

NAME                                      DISPLAY                         VERSION              REPLACES   PHASE
ibm-management-kong.v4.2.0-202309121245   IBM Internal - IBM AIOps Kong   4.2.0-202309121245              Succeeded

NAME                                               DISPLAY        VERSION              REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.2.0-202309121245   IBM AIOps UI   4.2.0-202309121245              Succeeded

______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.18.5   EDB Postgres for Kubernetes   1.18.5    cloud-native-postgresql.v1.18.4   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v3.25.7   IBM Cert Manager   3.25.7               Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v3.23.7   IBM Cloud Pak foundational services   3.23.7               Succeeded

NAME                            DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v1.21.7   Ibm Common UI   1.21.7               Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v4.8.0   IBM Events Operator   4.8.0                Succeeded

NAME                       DISPLAY   VERSION   REPLACES   PHASE
ibm-iam-operator.v3.23.7   IBM IAM   3.23.7               Succeeded

NAME                                 DISPLAY                      VERSION   REPLACES   PHASE
ibm-ingress-nginx-operator.v1.20.7   IBM Ingress Nginx Operator   1.20.7               Succeeded

NAME                             DISPLAY         VERSION   REPLACES   PHASE
ibm-licensing-operator.v1.20.7   IBM Licensing   1.20.7               Succeeded

NAME                                      DISPLAY              VERSION   REPLACES   PHASE
ibm-management-ingress-operator.v1.20.7   Management Ingress   1.20.7               Succeeded

NAME                           DISPLAY                VERSION   REPLACES   PHASE
ibm-mongodb-operator.v1.18.7   IBM MongoDB Operator   1.18.7               Succeeded

NAME                                   DISPLAY                       VERSION   REPLACES   PHASE
ibm-namespace-scope-operator.v1.17.7   IBM NamespaceScope Operator   1.17.7               Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-platform-api-operator.v3.25.7   IBM Platform API   3.25.7               Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v1.8.8   IBM Zen Service   1.8.8                Succeeded

NAME                                           DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v1.21.7   Operand Deployment Lifecycle Manager   1.21.7               Succeeded

______________________________________________________________
Subscriptions from katamari namespace:

NAME                 PACKAGE              SOURCE              CHANNEL
aimanager-operator   aimanager-operator   ibm-aiops-catalog   v4.2

NAME                 PACKAGE              SOURCE              CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-aiops-catalog   v4.2

NAME           PACKAGE        SOURCE              CHANNEL
asm-operator   asm-operator   ibm-aiops-catalog   v4.2

NAME                     PACKAGE                  SOURCE              CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-aiops-catalog   v4.2

NAME                     PACKAGE                  SOURCE              CHANNEL
ibm-automation-elastic   ibm-automation-elastic   ibm-aiops-catalog   v1.3

NAME                   PACKAGE                SOURCE              CHANNEL
ibm-automation-flink   ibm-automation-flink   ibm-aiops-catalog   v1.3

NAME                                                                        PACKAGE                       SOURCE              CHANNEL
ibm-common-service-operator-v3.23-ibm-aiops-catalog-openshift-marketplace   ibm-common-service-operator   ibm-aiops-catalog   v3.23

NAME                  PACKAGE               SOURCE              CHANNEL
ibm-management-kong   ibm-management-kong   ibm-aiops-catalog   v4.2

NAME                           PACKAGE                        SOURCE              CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-aiops-catalog   v4.2

NAME             PACKAGE           SOURCE              CHANNEL
ir-ai-operator   ibm-aiops-ir-ai   ibm-aiops-catalog   v4.2

NAME               PACKAGE             SOURCE              CHANNEL
ir-core-operator   ibm-aiops-ir-core   ibm-aiops-catalog   v4.2

NAME                    PACKAGE                  SOURCE              CHANNEL
ir-lifecycle-operator   ibm-aiops-ir-lifecycle   ibm-aiops-catalog   v4.2

NAME    PACKAGE                              SOURCE              CHANNEL
redis   ibm-cloud-databases-redis-operator   ibm-aiops-catalog   v1.6

______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                      PACKAGE                   SOURCE              CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-aiops-catalog   stable

NAME                        PACKAGE                     SOURCE              CHANNEL
ibm-cert-manager-operator   ibm-cert-manager-operator   ibm-aiops-catalog   v3.23

NAME                          PACKAGE                       SOURCE              CHANNEL
ibm-common-service-operator   ibm-common-service-operator   ibm-aiops-catalog   v3.23

NAME                    PACKAGE                     SOURCE              CHANNEL
ibm-commonui-operator   ibm-commonui-operator-app   ibm-aiops-catalog   v3.23

NAME                  PACKAGE               SOURCE              CHANNEL
ibm-events-operator   ibm-events-operator   ibm-aiops-catalog   v3

NAME               PACKAGE            SOURCE              CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-aiops-catalog   v3.23

NAME                         PACKAGE                          SOURCE              CHANNEL
ibm-ingress-nginx-operator   ibm-ingress-nginx-operator-app   ibm-aiops-catalog   v3.23

NAME                     PACKAGE                      SOURCE              CHANNEL
ibm-licensing-operator   ibm-licensing-operator-app   ibm-aiops-catalog   v3.23

NAME                              PACKAGE                               SOURCE              CHANNEL
ibm-management-ingress-operator   ibm-management-ingress-operator-app   ibm-aiops-catalog   v3.23

NAME                   PACKAGE                    SOURCE              CHANNEL
ibm-mongodb-operator   ibm-mongodb-operator-app   ibm-aiops-catalog   v3.23

NAME                           PACKAGE                        SOURCE              CHANNEL
ibm-namespace-scope-operator   ibm-namespace-scope-operator   ibm-aiops-catalog   v3.23

NAME                        PACKAGE                         SOURCE              CHANNEL
ibm-platform-api-operator   ibm-platform-api-operator-app   ibm-aiops-catalog   v3.23

NAME               PACKAGE            SOURCE              CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-aiops-catalog   v3.23

NAME                                       PACKAGE    SOURCE              CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-aiops-catalog   v3.23

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-ai-manager   Running   2023-09-19T18:44:21Z

NAMESPACE   NAME                         PHASE     CREATED AT
katamari    ibm-aiops-aiops-foundation   Running   2023-09-19T18:44:21Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-service   Running   2023-09-19T19:01:40Z

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   ibm-commonui-request   Running   2023-09-19T18:34:59Z

NAMESPACE             NAME              PHASE     CREATED AT
ibm-common-services   ibm-iam-request   Running   2023-09-19T18:34:59Z

NAMESPACE             NAME                  PHASE     CREATED AT
ibm-common-services   ibm-mongodb-request   Running   2023-09-19T18:36:08Z

NAMESPACE             NAME                 PHASE     CREATED AT
ibm-common-services   management-ingress   Running   2023-09-19T18:36:04Z

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   platform-api-request   Running   2023-09-19T18:36:05Z

______________________________________________________________
ODLM pod current status:

ibm-common-services                                operand-deployment-lifecycle-manager-577c5d4bcc-49mvw             1/1     Running            0               80m
______________________________________________________________
Orchestrator pod current status:

katamari                                           ibm-aiops-orchestrator-controller-manager-fd96f977b-sfbz6         1/1     Running            0               82m
```

### Upgrade status checker (`oc waiops status-upgrade`):
```
$ oc waiops status-upgrade
Cloud Pak for AIOps AI Manager v4.2 upgrade status:

______________________________________________________________

The following component(s) have finished upgrading:


KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.2.0     True     Ready

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   katamari    gateway   True     <none>

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.2.0     Completed   AI Manager is ready

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.2.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.2.0     Ready    All Services Ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.17.0    OK

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.2.0     Ready    All Services Ready

______________________________________________________________

```

## How to use

### Requirements
- You must have an installation of Cloud Pak for AIOps v3.3, v3.4, v3.5, v3.6, v3.7, v4.1, or v4.2 on your cluster. 

**Note**: while this tool does not require you to be logged in as a cluster admin, however
 * `oc waiops status-all`'s output will be limited if you are not. If possible, it is recommended to be logged in as a cluster admin to receive a more complete view of your install status.
 * `oc waiops multizone status` output may be limited and inaccurate without the required permissions

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

oc waiops multizone-status
oc waiops status
oc waiops status-all
oc waiops status-upgrade
```
