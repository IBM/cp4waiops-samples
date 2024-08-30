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
Already on project "cp4aiops" on server "https://my.cool.domain.com:6443".

Cloud Pak for AIOps v4.7 installation status:
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
    Rediscp:                         Ready
    Tunnel:                          Ready
    Zenservice:                      Ready
  Custom Profile Configmap:          aiops-custom-size-profile
  Custom Profile Validation Status:  Custom profile configmap not found, continue installation process without customization
  Image Pull Secret:                 Global
  Licenseacceptance:                 Accepted
  Locations:
    Cloud Pak Ui URL:     <url>
    Cs Admin Hub URL:     <url>
  Phase:                   Running
  Size:                    small
  Storageclass:            <storage class>
  Storageclasslargeblock:  <storage class block>
```


### Detailed installation status checker output (`oc waiops status-all`)
```
Cloud Pak for AIOps v4.7 installation status:
______________________________________________________________
Installation instances:

NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            154m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4aiops    5.1.7     Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   cp4aiops    iaf-system   True

KIND            NAMESPACE   NAME         STATUS
Elasticsearch   cp4aiops    iaf-system   True

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4aiops    aiops   4.7.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4aiops    aiops   4.7.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4aiops    aiops   4.7.0     Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4aiops    baseui-instance   4.7.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4aiops    aimanager   4.7.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4aiops    aiops-topology   2.25.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4aiops    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4aiops    aiopsui-instance   4.7.0     True     Ready

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                              STATUS
Cluster   cp4aiops    aiops-installation-edb-postgres   Cluster in healthy state
Cluster   cp4aiops    common-service-db                 Cluster in healthy state
Cluster   cp4aiops    zen-metastore-edb                 Cluster in healthy state

______________________________________________________________
FlinkDeployment:

NAME              JOB STATUS   LIFECYCLE STATE
aiops-lad-flink   FINISHED     STABLE

NAME                       JOB STATUS   LIFECYCLE STATE
aiops-ir-lifecycle-flink                STABLE

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   cp4aiops    sre-tunnel   True

______________________________________________________________
CSVs from cp4aiops namespace:

NAME                                     DISPLAY                VERSION              REPLACES   PHASE
aimanager-operator.v4.7.0-202408301445   IBM AIOps AI Manager   4.7.0-202408301445              Succeeded

NAME                                     DISPLAY          VERSION              REPLACES   PHASE
aiopsedge-operator.v4.7.0-202408301445   IBM AIOps Edge   4.7.0-202408301445              Succeeded

NAME                               DISPLAY                             VERSION              REPLACES   PHASE
asm-operator.v4.7.0-202408301445   IBM Netcool Agile Service Manager   4.7.0-202408301445              Succeeded

NAME                                  DISPLAY                                            VERSION              REPLACES   PHASE
ibm-aiops-ir-ai.v4.7.0-202408301445   IBM Watson AIOps Issue Resolution AI & Analytics   4.7.0-202408301445              Succeeded

NAME                                    DISPLAY                                  VERSION              REPLACES   PHASE
ibm-aiops-ir-core.v4.7.0-202408301445   IBM Watson AIOps Issue Resolution Core   4.7.0-202408301445              Succeeded

NAME                                         DISPLAY                                    VERSION              REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.7.0-202408301445   IBM Cloud Pak for Watson AIOps Lifecycle   4.7.0-202408301445              Succeeded

NAME                                         DISPLAY                   VERSION              REPLACES   PHASE
ibm-aiops-orchestrator.v4.7.0-202408301445   IBM Cloud Pak for AIOps   4.7.0-202408301445              Succeeded

NAME                             DISPLAY       VERSION   REPLACES   PHASE
ibm-automation-elastic.v1.3.16   IBM Elastic   1.3.16               Succeeded

NAME                           DISPLAY                          VERSION   REPLACES   PHASE
ibm-opencontent-flink.v2.0.3   IBM OpenContent Flink Operator   2.0.3                Succeeded

NAME                   DISPLAY                   VERSION   REPLACES   PHASE
ibm-redis-cp.v1.1.10   ibm-redis-cp-controller   1.1.10               Succeeded

NAME                                 DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.6.5   IBM Cloud Pak foundational services   4.6.5                Succeeded

NAME                                             DISPLAY             VERSION              REPLACES   PHASE
ibm-secure-tunnel-operator.v4.7.0-202408301445   IBM Secure Tunnel   4.7.0-202408301445              Succeeded

NAME                                               DISPLAY        VERSION              REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.7.0-202408301445   IBM AIOps UI   4.7.0-202408301445              Succeeded

NAME                               DISPLAY                       VERSION   REPLACES                           PHASE
cloud-native-postgresql.v1.18.13   EDB Postgres for Kubernetes   1.18.13   cloud-native-postgresql.v1.18.12   Succeeded

NAME                               DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.7   IBM Cert Manager   4.2.7                Succeeded

NAME                           DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.4.4   Ibm Common UI   4.4.4                Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v5.0.1   IBM Events Operator   5.0.1                Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.5.4   IBM IM Operator   4.5.4                Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v5.1.7   IBM Zen Service   5.1.7                Succeeded

NAME                                          DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.3.4   Operand Deployment Lifecycle Manager   4.3.4                Succeeded

______________________________________________________________
Subscriptions from cp4aiops namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.7

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.7

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.7

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.7

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-automation-elastic   ibm-automation-elastic   ibm-cp-waiops-catalog   v1.3

NAME                    PACKAGE                 SOURCE                  CHANNEL
ibm-opencontent-flink   ibm-opencontent-flink   ibm-cp-waiops-catalog   v2.0

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.7

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.7

NAME             PACKAGE           SOURCE                  CHANNEL
ir-ai-operator   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.7

NAME               PACKAGE             SOURCE                  CHANNEL
ir-core-operator   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.7

NAME                    PACKAGE                  SOURCE                  CHANNEL
ir-lifecycle-operator   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.7

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
cp4aiops    ibm-aiops-ai-manager   Running   2024-08-30T15:39:02Z

NAMESPACE   NAME                         PHASE     CREATED AT
cp4aiops    ibm-aiops-aiops-foundation   Running   2024-08-30T15:39:02Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-connection   Running   2024-08-30T15:39:02Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-service   Running   2024-08-30T15:39:32Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-request   Running   2024-08-30T15:36:33Z

______________________________________________________________
AIOps certificate status:

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2024-10-29T16:06:09Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-appconnect-ir-cert   2025-12-30T07:40:54Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-client-cert   2024-10-29T15:39:27Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-server-cert   2024-10-29T15:39:27Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-ss-ca   2024-10-29T15:39:09Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2024-10-29T15:33:33Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2024-10-29T15:33:33Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
aiops-installation-redis-ss-ca   2024-10-29T15:33:18Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-installation-tls-ca   2024-10-29T15:33:37Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-classifier   2024-10-29T15:49:48Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-api   2024-10-29T15:49:45Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-spark   2024-10-29T15:49:42Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-ir-analytics-probablecause   2024-10-29T15:44:45Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-master   2024-10-29T15:49:48Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-pipeline-composer   2024-10-29T15:49:40Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-ir-core-api   2024-10-29T15:45:46Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-archiving   2024-10-29T15:45:46Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-cem-users   2024-10-29T15:45:46Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-couchdb-api   2024-10-29T15:44:26Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-esarchiving   2024-10-29T15:45:45Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncobackup   2024-10-29T15:45:45Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-api   2024-10-29T15:45:40Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr   2024-10-29T15:45:44Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-std   2024-10-29T15:45:56Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-core-ncoprimary   2024-10-29T15:45:18Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-repl   2024-10-29T15:47:09Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-ir-core-rba-as   2024-10-29T15:45:50Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-rba-rbs   2024-10-29T15:45:45Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-usercfg   2024-10-29T15:45:52Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink   2024-10-29T15:40:48Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-api   2024-10-29T15:40:52Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-rest   2024-10-29T15:40:46Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-policy-registry-svc   2024-10-29T15:40:35Z   True    Certificate is up to date and has not expired

NAME              RENEWAL                READY   MESSAGE
aiops-lad-flink   2024-10-29T15:36:23Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
aiops-lad-flink-api   2024-10-29T15:36:25Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-lad-flink-rest   2024-10-29T15:36:28Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2031-04-29T23:42:14Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-file-observer-cert   2024-11-17T19:42:06Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-inventory-cert   2024-11-17T19:42:26Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-kubernetes-observer-cert   2024-11-17T19:42:42Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-layout-cert   2024-11-17T19:42:25Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-topology-merge-cert   2024-11-17T19:42:48Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-observer-service-cert   2024-11-17T19:42:09Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-rest-observer-cert   2024-11-17T19:42:29Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-servicenow-observer-cert   2024-11-17T19:42:29Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-sevone-observer-cert   2024-11-17T19:42:38Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-status-cert   2024-11-17T19:42:43Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-topology-topology-cert   2024-11-17T19:42:33Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-ui-api-cert   2024-11-17T19:42:38Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmvcenter-observer-cert   2024-11-17T19:42:34Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ui-tls-certificate   2024-10-29T16:05:46Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2026-07-31T15:41:58Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-generic-topology-cert-a15ced70   2025-12-30T07:44:03Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-im-topology-inte-cert-ee825c9a   2025-12-30T07:44:14Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-instana-topology-cert-f8c9d506   2025-12-30T07:44:13Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2026-07-31T15:40:49Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2024-10-29T15:35:54Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2024-10-29T15:36:52Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2024-10-29T15:37:06Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2025-07-31T15:37:17Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2024-10-29T15:37:10Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2025-06-04T15:37:26Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-f4b5d4eb   2025-12-30T07:43:54Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
connector-manager-cert-8c1c63ec   2025-12-30T07:43:56Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
connector-orchestrator-cert-6b61c3a1   2025-12-30T07:43:47Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
cp4waiops-connectors-deploy   2025-12-30T07:40:57Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2025-12-30T07:35:44Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
flink-operator-cert   2024-10-29T15:35:53Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
iaf-system-elasticsearch-es-client-cert   2024-10-29T15:37:37Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
iaf-system-elasticsearch-es-ss-ca   2024-10-29T15:37:10Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2024-10-29T15:54:53Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2025-06-04T15:37:06Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2024-10-29T15:42:55Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2024-10-29T15:42:44Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2024-10-29T15:42:50Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2025-06-04T15:36:55Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2025-06-04T15:36:54Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2025-06-04T15:36:53Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2031-04-30T00:19:07Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2031-04-30T00:19:00Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2031-04-30T00:19:06Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2024-10-29T15:42:54Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2025-07-31T15:42:49Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2025-08-30T15:44:05Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

cp4aiops                                           operand-deployment-lifecycle-manager-7bd6849df5-b2642                     1/1     Running     0               154m
______________________________________________________________
Orchestrator pod current status:

cp4aiops                                           ibm-aiops-orchestrator-controller-manager-864664bccb-l8zxm                1/1     Running     0               158m

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
