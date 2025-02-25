<!-- © Copyright IBM Corp. 2020, 2025-->

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
Cloud Pak for AIOps v4.9 installation status:
______________________________________________________________
Installation instances:

NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            3h16m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4aiops    5.1.12    Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   cp4aiops    iaf-system   True

KIND                   NAMESPACE   NAME    STATUS
ElasticsearchCluster   cp4aiops    aiops   Ready

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4aiops    aiops   4.9.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4aiops    aiops   4.9.0     Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4aiops    aiops   4.9.0     Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4aiops    baseui-instance   4.9.0     True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4aiops    aimanager   4.9.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4aiops    aiops-topology   2.28.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4aiops    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4aiops    aiopsui-instance   4.9.0     True     Ready

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                              STATUS
Cluster   cp4aiops    aiops-installation-edb-postgres   Cluster in healthy state
Cluster   cp4aiops    common-service-db                 Cluster in healthy state
Cluster   cp4aiops    zen-metastore-edb                 Cluster in healthy state

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   cp4aiops    sre-tunnel   True

______________________________________________________________
CSVs from cp4aiops namespace:

NAME                                     DISPLAY                VERSION              REPLACES   PHASE
aimanager-operator.v4.9.0-202502251245   IBM AIOps AI Manager   4.9.0-202502251245              Succeeded

NAME                                     DISPLAY          VERSION              REPLACES   PHASE
aiopsedge-operator.v4.9.0-202502251245   IBM AIOps Edge   4.9.0-202502251245              Succeeded

NAME                               DISPLAY                             VERSION              REPLACES   PHASE
asm-operator.v4.9.0-202502251245   IBM Netcool Agile Service Manager   4.9.0-202502251245              Succeeded

NAME                                  DISPLAY                                            VERSION              REPLACES   PHASE
ibm-aiops-ir-ai.v4.9.0-202502251245   IBM Watson AIOps Issue Resolution AI & Analytics   4.9.0-202502251245              Succeeded

NAME                                    DISPLAY                                  VERSION              REPLACES   PHASE
ibm-aiops-ir-core.v4.9.0-202502251245   IBM Watson AIOps Issue Resolution Core   4.9.0-202502251245              Succeeded

NAME                                         DISPLAY                                    VERSION              REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.9.0-202502251245   IBM Cloud Pak for Watson AIOps Lifecycle   4.9.0-202502251245              Succeeded

NAME                                         DISPLAY                   VERSION              REPLACES   PHASE
ibm-aiops-orchestrator.v4.9.0-202502251245   IBM Cloud Pak for AIOps   4.9.0-202502251245              Succeeded

NAME                                   DISPLAY                         VERSION    REPLACES   PHASE
ibm-elasticsearch-operator.v1.1.2570   IBM OpenContent Elasticsearch   1.1.2570              Succeeded

NAME                           DISPLAY                          VERSION   REPLACES   PHASE
ibm-opencontent-flink.v2.0.8   IBM OpenContent Flink Operator   2.0.8                Succeeded

NAME                  DISPLAY                   VERSION   REPLACES   PHASE
ibm-redis-cp.v1.2.4   ibm-redis-cp-controller   1.2.4                Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.6.10   IBM Cloud Pak foundational services   4.6.10               Succeeded

NAME                                             DISPLAY             VERSION              REPLACES   PHASE
ibm-secure-tunnel-operator.v4.9.0-202502251245   IBM Secure Tunnel   4.9.0-202502251245              Succeeded

NAME                                               DISPLAY        VERSION              REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.9.0-202502251245   IBM AIOps UI   4.9.0-202502251245              Succeeded

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.22.8   EDB Postgres for Kubernetes   1.22.8    cloud-native-postgresql.v1.22.7   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.12   IBM Cert Manager   4.2.12               Succeeded

NAME                           DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.4.9   Ibm Common UI   4.4.9                Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v5.0.1   IBM Events Operator   5.0.1                Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.5.9   IBM IM Operator   4.5.9                Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v5.1.12   IBM Zen Service   5.1.12               Succeeded

NAME                                          DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.3.9   Operand Deployment Lifecycle Manager   4.3.9                Succeeded

______________________________________________________________
Subscriptions from cp4aiops namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.9

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.9

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.9

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.9

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-elasticsearch-operator   ibm-elasticsearch-operator   ibm-cp-waiops-catalog   v1.1

NAME                    PACKAGE                 SOURCE                  CHANNEL
ibm-opencontent-flink   ibm-opencontent-flink   ibm-cp-waiops-catalog   v2.0

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.9

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.9

NAME              PACKAGE           SOURCE                  CHANNEL
ibm-aiops-ir-ai   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.9

NAME                PACKAGE             SOURCE                  CHANNEL
ibm-aiops-ir-core   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.9

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-ir-lifecycle   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.9

NAME           PACKAGE        SOURCE                  CHANNEL
ibm-redis-cp   ibm-redis-cp   ibm-cp-waiops-catalog   v1.2

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable-v1.22

NAME                        PACKAGE                     SOURCE                  CHANNEL
ibm-commonui-operator-app   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v4.4

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v3

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-cp-waiops-catalog   v4.5

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-cp-waiops-catalog   v4.4

NAME                                       PACKAGE    SOURCE                  CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-cp-waiops-catalog   v4.3

NAME                        PACKAGE                       SOURCE                  CHANNEL
aiops-ibm-common-services   ibm-common-service-operator   ibm-cp-waiops-catalog   v4.6

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-ai-manager   Running   2025-02-25T13:14:01Z

NAMESPACE   NAME                         PHASE     CREATED AT
cp4aiops    ibm-aiops-aiops-foundation   Running   2025-02-25T13:14:01Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-connection   Running   2025-02-25T13:14:01Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-service   Running   2025-02-25T13:16:38Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-request   Running   2025-02-25T13:14:16Z

______________________________________________________________
AIOps certificate status:

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2025-04-26T13:36:48Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-appconnect-ir-cert   2025-04-26T13:15:38Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-elastic-tls   2025-04-26T13:13:56Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-client-cert   2025-04-26T13:14:31Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-server-cert   2025-04-26T13:14:26Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-installation-edb-postgres-ss-ca   2025-04-26T13:14:11Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2025-04-26T13:10:49Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2025-04-26T13:10:49Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
aiops-installation-redis-ss-ca   2025-04-26T13:10:48Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-installation-tls-ca   2025-04-26T13:10:53Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-classifier   2025-04-26T13:25:51Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-api   2025-04-26T13:25:52Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-spark   2025-04-26T13:25:53Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-ir-analytics-probablecause   2025-04-26T13:20:30Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-master   2025-04-26T13:26:01Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-pipeline-composer   2025-04-26T13:25:57Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-ir-core-api   2025-04-26T13:21:39Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-archiving   2025-04-26T13:21:38Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-cem-users   2025-04-26T13:21:39Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-couchdb-api   2025-04-26T13:20:25Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-esarchiving   2025-04-26T13:21:17Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncobackup   2025-04-26T13:21:36Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-api   2025-04-26T13:21:41Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-if   2025-04-26T13:21:44Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr   2025-04-26T13:21:23Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-std   2025-04-26T13:21:48Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-core-ncoprimary   2025-04-26T13:21:41Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-ir-core-rba-as   2025-04-26T13:21:32Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-rba-rbs   2025-04-26T13:21:48Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-usercfg   2025-04-26T13:21:46Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink   2025-04-26T13:15:42Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-api   2025-04-26T13:15:46Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-rest   2025-04-26T13:15:41Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-policy-registry-svc   2025-04-26T13:15:37Z   True    Certificate is up to date and has not expired

NAME              RENEWAL                READY   MESSAGE
aiops-lad-flink   2025-04-26T13:14:03Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
aiops-lad-flink-api   2025-04-26T13:13:46Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-lad-flink-rest   2025-04-26T13:13:51Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2031-10-25T21:17:35Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-file-observer-cert   2025-05-15T17:17:54Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-inventory-cert   2025-05-15T17:17:27Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-kubernetes-observer-cert   2025-05-15T17:17:20Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-layout-cert   2025-05-15T17:17:47Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-topology-merge-cert   2025-05-15T17:17:57Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-observer-service-cert   2025-05-15T17:17:38Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-rest-observer-cert   2025-05-15T17:17:47Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-servicenow-observer-cert   2025-05-15T17:17:40Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-sevone-observer-cert   2025-05-15T17:17:33Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-status-cert   2025-05-15T17:17:47Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-topology-topology-cert   2025-05-15T17:17:47Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-ui-api-cert   2025-05-15T17:17:54Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmvcenter-observer-cert   2025-05-15T17:17:51Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ui-tls-certificate   2025-04-26T13:36:20Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2027-01-26T13:16:41Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-generic-topology-cert-e96f1f80   2025-04-26T13:18:50Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-im-topology-inte-cert-b6f0cde3   2025-04-26T13:18:59Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-instana-topology-cert-ad0a37c3   2025-04-26T13:19:05Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2027-01-26T13:15:37Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2025-04-26T13:12:50Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2025-04-26T13:14:48Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2025-04-26T13:14:46Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2026-01-26T13:14:51Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2025-04-26T13:14:54Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2025-11-30T13:16:05Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-f7ab618b   2026-06-27T05:18:37Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
connector-manager-cert-697fdd53   2025-04-26T13:18:35Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
connector-orchestrator-cert-306617b2   2025-04-26T13:18:42Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
cp4waiops-connectors-deploy   2025-04-26T13:15:38Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2026-06-27T05:13:01Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
flink-operator-cert   2025-04-26T13:12:49Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2025-04-26T13:25:31Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2025-11-30T13:14:48Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2025-04-26T13:19:20Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2025-04-26T13:19:16Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2025-04-26T13:19:09Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2025-11-30T13:14:26Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2025-11-30T13:14:33Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2025-11-30T13:14:51Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2031-10-25T21:37:52Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2031-10-25T21:37:47Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2031-10-25T21:37:52Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2025-04-26T13:19:21Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2026-01-26T13:19:16Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2026-02-25T13:20:21Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

cp4aiops                                           operand-deployment-lifecycle-manager-7476f497cb-m2twh                     1/1     Running     0               3h16m
______________________________________________________________
Orchestrator pod current status:

cp4aiops                                           ibm-aiops-orchestrator-controller-manager-84b8bcbd4f-9djcq                1/1     Running     0               3h20m
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
