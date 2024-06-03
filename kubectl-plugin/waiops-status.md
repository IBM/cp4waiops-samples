<!-- © Copyright IBM Corp. 2020, 2024-->

#### ***NOTE**: from CP4AIOps v4.1.0 onwards, the use of the status, status-all, status-upgrade functions are now considered **deprecated**. Please primarily refer to the installation status messages provided directly in the installation.orchestrator.aiops.ibm.com CR instance of your cluster's installation.*

# kubectl-waiops

A kubectl plugin for CP4AIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
Run `oc waiops multizone status` to view how well the installation is prepared for a zone outage.
Run `oc waiops multizone pods` to view which zone each pod is in.
  * **NOTE**: These functions require bash to be at least version **4**  (MacOS ships with a very old version)
  * **NOTE**: If you have installed/upgraded bash to a path other than `/bin/bash` change the first line of the script to that fully qualified path.

Run `oc waiops status` to print the statuses of some of your instance's main components. If you see components with issues (or are generally facing issues on your cluster), run `oc waiops status-all` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status`)
```
$ oc waiops status
Already on project "katamari" on server "https://api.my.cool.domain.com:6443".

Cloud Pak for AIOps v4.6 installation status:
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
    Lifecycleservice:                Ready
    Lifecycletrigger:                Ready
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
Already on project "katamari" on server "https://api.my.cool.domain.com:6443".

Cloud Pak for AIOps v4.6 installation status:
______________________________________________________________
Installation instances:

NAME                 PHASE     LICENSE    STORAGECLASS                STORAGECLASSLARGEBLOCK        AGE
aiops-installation   Running   Accepted   ocs-storagecluster-cephfs   ocs-storagecluster-ceph-rbd   113m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   katamari    5.1.4     Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   katamari    iaf-system   True

KIND            NAMESPACE   NAME         STATUS
Elasticsearch   katamari    iaf-system   True

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.6.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.6.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.6.0     Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   katamari    baseui-instance   4.6.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.6.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.24.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.6.0     True     Ready

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                              STATUS
Cluster   katamari    aiops-installation-edb-postgres   Cluster in healthy state
Cluster   katamari    common-service-db                 Cluster in healthy state
Cluster   katamari    zen-metastore-edb                 Cluster in healthy state

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   katamari    sre-tunnel   True

______________________________________________________________
CSVs from katamari namespace:

NAME                                     DISPLAY                VERSION              REPLACES   PHASE
aimanager-operator.v4.6.0-202405230445   IBM AIOps AI Manager   4.6.0-202405230445              Succeeded

NAME                                     DISPLAY          VERSION              REPLACES   PHASE
aiopsedge-operator.v4.6.0-202405230445   IBM AIOps Edge   4.6.0-202405230445              Succeeded

NAME                               DISPLAY                             VERSION              REPLACES   PHASE
asm-operator.v4.6.0-202405230445   IBM Netcool Agile Service Manager   4.6.0-202405230445              Succeeded

NAME                                  DISPLAY                                            VERSION              REPLACES   PHASE
ibm-aiops-ir-ai.v4.6.0-202405230445   IBM Watson AIOps Issue Resolution AI & Analytics   4.6.0-202405230445              Succeeded

NAME                                    DISPLAY                                  VERSION              REPLACES   PHASE
ibm-aiops-ir-core.v4.6.0-202405230445   IBM Watson AIOps Issue Resolution Core   4.6.0-202405230445              Succeeded

NAME                                         DISPLAY                                    VERSION              REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.6.0-202405230445   IBM Cloud Pak for Watson AIOps Lifecycle   4.6.0-202405230445              Succeeded

NAME                                         DISPLAY                   VERSION              REPLACES   PHASE
ibm-aiops-orchestrator.v4.6.0-202405230445   IBM Cloud Pak for AIOps   4.6.0-202405230445              Succeeded

NAME                             DISPLAY       VERSION   REPLACES   PHASE
ibm-automation-elastic.v1.3.16   IBM Elastic   1.3.16               Succeeded

NAME                           DISPLAY                           VERSION   REPLACES   PHASE
ibm-automation-flink.v1.3.16   IBM Automation Foundation Flink   1.3.16               Succeeded

NAME                  DISPLAY                 VERSION   REPLACES   PHASE
ibm-redis-cp.v1.1.9   ibm-redis-cp-operator   1.1.9                Succeeded

NAME                                 DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.6.2   IBM Cloud Pak foundational services   4.6.2                Succeeded

NAME                                             DISPLAY             VERSION              REPLACES   PHASE
ibm-secure-tunnel-operator.v4.6.0-202405230445   IBM Secure Tunnel   4.6.0-202405230445              Succeeded

NAME                                               DISPLAY        VERSION              REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.6.0-202405230445   IBM AIOps UI   4.6.0-202405230445              Succeeded

NAME                               DISPLAY                       VERSION   REPLACES                           PHASE
cloud-native-postgresql.v1.18.12   EDB Postgres for Kubernetes   1.18.12   cloud-native-postgresql.v1.18.10   Succeeded

NAME                               DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.4   IBM Cert Manager   4.2.4                Succeeded

NAME                           DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.4.1   Ibm Common UI   4.4.1                Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v5.0.1   IBM Events Operator   5.0.1                Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.5.1   IBM IM Operator   4.5.1                Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v5.1.4   IBM Zen Service   5.1.4                Succeeded

NAME                                          DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.3.1   Operand Deployment Lifecycle Manager   4.3.1                Succeeded

______________________________________________________________
Subscriptions from katamari namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.6

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.6

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.6

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.6

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-automation-elastic   ibm-automation-elastic   ibm-cp-waiops-catalog   v1.3

NAME                   PACKAGE                SOURCE                  CHANNEL
ibm-automation-flink   ibm-automation-flink   ibm-cp-waiops-catalog   v1.3

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.6

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.6

NAME             PACKAGE           SOURCE                  CHANNEL
ir-ai-operator   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.6

NAME               PACKAGE             SOURCE                  CHANNEL
ir-core-operator   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.6

NAME                    PACKAGE                  SOURCE                  CHANNEL
ir-lifecycle-operator   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.6

NAME           PACKAGE        SOURCE                  CHANNEL
ibm-redis-cp   ibm-redis-cp   ibm-cp-waiops-catalog   v1.1

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable

NAME                         PACKAGE                     SOURCE                  CHANNEL
ibm-idp-config-ui-operator   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v4.4

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v3

NAME              PACKAGE            SOURCE                  CHANNEL
ibm-im-operator   ibm-iam-operator   ibm-cp-waiops-catalog   v4.5

NAME                      PACKAGE            SOURCE                  CHANNEL
ibm-platformui-operator   ibm-zen-operator   ibm-cp-waiops-catalog   v4.4

NAME                                       PACKAGE    SOURCE                  CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-cp-waiops-catalog   v4.3

NAME                        PACKAGE                       SOURCE                  CHANNEL
aiops-ibm-common-services   ibm-common-service-operator   ibm-cp-waiops-catalog   v4.6

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-ai-manager   Running   2024-05-23T05:43:18Z

NAMESPACE   NAME                         PHASE     CREATED AT
katamari    ibm-aiops-aiops-foundation   Running   2024-05-23T05:43:18Z

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-connection   Running   2024-05-23T05:43:18Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-service   Running   2024-05-23T05:46:13Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-request   Running   2024-05-23T05:43:02Z

______________________________________________________________
AIOps certificate status:

NAME                       RENEWAL                READY   MESSAGE
aimanager-ca-certificate   2024-07-22T06:10:37Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2024-07-22T06:10:59Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-client-cert   2024-07-22T05:43:45Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-server-cert   2024-07-22T05:43:48Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-ss-ca   2024-07-22T05:43:32Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2024-07-22T05:39:47Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2024-07-22T05:39:47Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
aiops-installation-redis-ss-ca   2024-07-22T05:39:30Z   True    Certificate is up to date and has not expired

NAME                                               RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-eventprocessor-ep-client-cert   2024-07-22T05:46:12Z   True    Certificate is up to date and has not expired

NAME                                                 RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-eventprocessor-ep-internal-cert   2024-07-22T05:46:12Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-eventprocessor-ep-ss-ca   2024-07-22T05:45:44Z   True    Certificate is up to date and has not expired

NAME                                                  RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-eventprocessor-ep-zk-client-cert   2024-07-17T05:45:51Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2031-01-20T13:52:18Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2026-04-23T05:46:51Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2026-04-23T05:45:45Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2024-07-22T05:41:51Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2024-07-22T05:44:13Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2024-07-22T05:43:59Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2025-04-23T05:44:12Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2024-07-22T05:44:16Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2025-02-25T05:45:52Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-abf2462c   2025-09-21T21:51:44Z   True    Certificate is up to date and has not expired

NAME                                               RENEWAL                READY   MESSAGE
cp4waiops-eventprocessor-eve-29ee-ep-client-cert   2024-07-22T05:43:46Z   True    Certificate is up to date and has not expired

NAME                                                 RENEWAL                READY   MESSAGE
cp4waiops-eventprocessor-eve-29ee-ep-internal-cert   2024-07-22T05:43:43Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
cp4waiops-eventprocessor-eve-29ee-ep-ss-ca   2024-07-22T05:43:42Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2025-09-21T21:42:16Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
iaf-system-elasticsearch-es-client-cert   2024-07-22T05:44:58Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
iaf-system-elasticsearch-es-ss-ca   2024-07-22T05:43:54Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2024-07-22T05:57:06Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2025-02-25T05:43:13Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2024-07-22T05:50:32Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2024-07-22T05:50:27Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2024-07-22T05:50:18Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2025-02-25T05:43:16Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2025-02-25T05:43:09Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2025-02-25T05:43:40Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2031-01-20T14:24:02Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2031-01-20T14:23:59Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2031-01-20T14:24:03Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2024-07-22T05:50:30Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2025-04-23T05:50:33Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2025-05-23T05:51:48Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

katamari                                           operand-deployment-lifecycle-manager-7fc6dfccf4-f55q5                     1/1     Running     0               113m
______________________________________________________________
Orchestrator pod current status:

katamari                                           ibm-aiops-orchestrator-controller-manager-6bb594497f-sfc4l                1/1     Running     0               117m
```

### Upgrade status checker (`oc waiops status-upgrade`):
```
$ oc waiops status-upgrade
Now using project "katamari" on server "https://my.cool.domain.com:6443".

Cloud Pak for AIOps v4.6 upgrade status:

______________________________________________________________

The following component(s) have finished upgrading:


KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.6.0     Ready    All Services Ready

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.6.0     True     Ready

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.6.0     Completed   AI Manager is ready

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.6.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.6.0     Ready    All Services Ready

KIND     NAMESPACE   NAME         STATUS
Tunnel   katamari    sre-tunnel   True

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.24.0    OK

______________________________________________________________

Hint: for a more detailed printout of component statuses, run `oc waiops status` or `oc waiops status-all`.

```

## How to use

### Requirements
- You must have an installation of Cloud Pak for AIOps v3.x or v4.x on your cluster. 

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
