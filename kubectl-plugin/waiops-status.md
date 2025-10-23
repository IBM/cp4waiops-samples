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

Run `oc waiops status <namespace>` to print the statuses of some of your instance's main components. If you see components with issues (or are generally facing issues on your cluster), run `oc waiops status-all <namespace>` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade <namespace>`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status cp4aiops`)
```
$ oc waiops status cp4aiops
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


### Detailed installation status checker output (`oc waiops status-all cp4aiops`)
``` 
______________________________________________________________
Installation instances:

NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            138m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   katamari    5.1.17    Completed   100%       The Current Operation Is Completed

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   katamari    iaf-system   True

KIND      NAMESPACE   NAME               STATUS
Cluster   katamari    aiops-opensearch   Available

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   katamari    aiops   4.11.1    Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   katamari    aiops   4.11.1    Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   katamari    aiops   4.11.1    Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   katamari    baseui-instance   4.11.1    True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   katamari    aimanager   4.11.1    Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    katamari    aiops-topology   2.31.1    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   katamari    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   katamari    aiopsui-instance   4.11.1    True     Ready

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                          STATUS
Cluster   katamari    aiops-ir-analytics-postgres   Cluster in healthy state
Cluster   katamari    aiops-ir-core-postgres        Cluster in healthy state
Cluster   katamari    aiops-orchestrator-postgres   Cluster in healthy state
Cluster   katamari    aiops-topology-postgres       Cluster in healthy state
Cluster   katamari    common-service-db             Cluster in healthy state
Cluster   katamari    zen-metastore-edb             Cluster in healthy state

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   katamari    sre-tunnel   True

______________________________________________________________
CSVs from katamari namespace:

NAME                                      DISPLAY                VERSION               REPLACES   PHASE
aimanager-operator.v4.11.1-202510201245   IBM AIOps AI Manager   4.11.1-202510201245              Succeeded

NAME                                      DISPLAY          VERSION               REPLACES   PHASE
aiopsedge-operator.v4.11.1-202510201245   IBM AIOps Edge   4.11.1-202510201245              Succeeded

NAME                                DISPLAY                             VERSION               REPLACES   PHASE
asm-operator.v4.11.1-202510201245   IBM Netcool Agile Service Manager   4.11.1-202510201245              Succeeded

NAME                                   DISPLAY                                            VERSION               REPLACES   PHASE
ibm-aiops-ir-ai.v4.11.1-202510201245   IBM Watson AIOps Issue Resolution AI & Analytics   4.11.1-202510201245              Succeeded

NAME                                     DISPLAY                                  VERSION               REPLACES   PHASE
ibm-aiops-ir-core.v4.11.1-202510201245   IBM Watson AIOps Issue Resolution Core   4.11.1-202510201245              Succeeded

NAME                                          DISPLAY                                    VERSION               REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.11.1-202510201245   IBM Cloud Pak for Watson AIOps Lifecycle   4.11.1-202510201245              Succeeded

NAME                                          DISPLAY                   VERSION               REPLACES   PHASE
ibm-aiops-orchestrator.v4.11.1-202510201245   IBM Cloud Pak for AIOps   4.11.1-202510201245              Succeeded

NAME                                DISPLAY                   VERSION    REPLACES   PHASE
ibm-opensearch-operator.v1.1.4002   IBM Opensearch Operator   1.1.4002              Succeeded

NAME                            DISPLAY                          VERSION   REPLACES   PHASE
ibm-opencontent-flink.v2.0.14   IBM OpenContent Flink Operator   2.0.14               Succeeded

NAME                  DISPLAY                   VERSION   REPLACES   PHASE
ibm-redis-cp.v1.2.9   ibm-redis-cp-controller   1.2.9                Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.6.18   IBM Cloud Pak foundational services   4.6.18               Succeeded

NAME                                              DISPLAY             VERSION               REPLACES   PHASE
ibm-secure-tunnel-operator.v4.11.1-202510201245   IBM Secure Tunnel   4.11.1-202510201245              Succeeded

NAME                                                DISPLAY        VERSION               REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.11.1-202510201245   IBM AIOps UI   4.11.1-202510201245              Succeeded

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.25.2   EDB Postgres for Kubernetes   1.25.2    cloud-native-postgresql.v1.25.1   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.18   IBM Cert Manager   4.2.18               Succeeded

NAME                            DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.4.15   Ibm Common UI   4.4.15               Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v5.2.1   IBM Events Operator   5.2.1                Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.5.15   IBM IM Operator   4.5.15               Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v5.1.17   IBM Zen Service   5.1.17               Succeeded

NAME                                           DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.3.16   Operand Deployment Lifecycle Manager   4.3.16               Succeeded

______________________________________________________________
Subscriptions from katamari namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.11

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.11

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.11

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.11

NAME                      PACKAGE                   SOURCE                  CHANNEL
ibm-opensearch-operator   ibm-opensearch-operator   ibm-cp-waiops-catalog   v1.1

NAME                    PACKAGE                 SOURCE                  CHANNEL
ibm-opencontent-flink   ibm-opencontent-flink   ibm-cp-waiops-catalog   v2.0

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.11

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.11

NAME              PACKAGE           SOURCE                  CHANNEL
ibm-aiops-ir-ai   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.11

NAME                PACKAGE             SOURCE                  CHANNEL
ibm-aiops-ir-core   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.11

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-ir-lifecycle   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.11

NAME           PACKAGE        SOURCE                  CHANNEL
ibm-redis-cp   ibm-redis-cp   ibm-cp-waiops-catalog   v1.2

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable-v1.25

NAME                        PACKAGE                     SOURCE                  CHANNEL
ibm-commonui-operator-app   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v4.4

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v5.2

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
katamari    ibm-aiops-ai-manager   Running   2025-10-23T11:12:14Z

NAMESPACE   NAME                         PHASE     CREATED AT
katamari    ibm-aiops-aiops-foundation   Running   2025-10-23T11:12:13Z

NAMESPACE   NAME                   PHASE     CREATED AT
katamari    ibm-aiops-connection   Running   2025-10-23T11:12:14Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-service   Running   2025-10-23T11:15:37Z

NAMESPACE   NAME              PHASE     CREATED AT
katamari    ibm-iam-request   Running   2025-10-23T11:11:37Z

______________________________________________________________
AIOps certificate status:

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2025-12-22T11:46:11Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-appconnect-ir-cert   2025-12-22T11:15:16Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2025-12-22T11:09:05Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2025-12-22T11:08:48Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
aiops-installation-redis-ss-ca   2025-12-22T11:08:47Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-installation-tls-ca   2025-12-22T11:09:21Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-classifier   2025-12-22T11:43:50Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-api   2025-12-22T11:44:34Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-spark   2025-12-22T11:44:36Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-client-cert   2025-12-22T11:15:47Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-server-cert   2025-12-22T11:15:39Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-ir-analytics-probablecause   2025-12-22T11:36:29Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-master   2025-12-22T11:44:23Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-pipeline-composer   2025-12-22T11:43:52Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-ir-core-api   2025-12-22T11:39:20Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-archiving   2025-12-22T11:39:50Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-cem-users   2025-12-22T11:40:19Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-couchdb-api   2025-12-22T11:33:34Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-esarchiving   2025-12-22T11:39:50Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncobackup   2025-12-22T11:36:03Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-api   2025-12-22T11:39:48Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-if   2025-12-22T11:39:49Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr   2025-12-22T11:39:49Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-std   2025-12-22T11:40:20Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-core-ncoprimary   2025-12-22T11:35:12Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-client-cert   2025-12-22T11:15:35Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-server-cert   2025-12-22T11:15:52Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-ir-core-rba-as   2025-12-22T11:40:08Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-rba-rbs   2025-12-22T11:39:52Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-usercfg   2025-12-22T11:40:11Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink   2025-12-22T11:15:35Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-api   2025-12-22T11:14:45Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-rest   2025-12-22T11:15:09Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-zk-client   2025-12-17T11:16:00Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-policy-registry-svc   2025-12-22T11:15:11Z   True    Certificate is up to date and has not expired

NAME              RENEWAL                READY   MESSAGE
aiops-lad-flink   2025-12-22T11:11:41Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
aiops-lad-flink-api   2025-12-22T11:12:11Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-lad-flink-rest   2025-12-22T11:12:07Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-lad-flink-zk-client   2025-12-22T11:11:37Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-opensearch-tls   2025-12-22T11:12:35Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-client-cert   2025-12-22T11:12:38Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-server-cert   2025-12-22T11:12:30Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
aiops-topology-aaionap-cert   2026-01-10T15:24:54Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-alm-observer-cert   2026-01-10T15:24:59Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-ansibleawx-observer-cert   2026-01-10T15:24:58Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-appdynamics-observer-cert   2026-01-10T15:25:05Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-aws-observer-cert   2026-01-10T15:24:14Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-azure-observer-cert   2026-01-10T15:20:31Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-bigcloudfabric-observer-cert   2026-01-10T15:19:50Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-bigfixinventory-observer-cert   2026-01-10T15:25:09Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2032-06-21T19:19:23Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-cienablueplanet-observer-cert   2026-01-10T15:24:59Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ciscoaci-observer-cert   2026-01-10T15:25:07Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-contrail-observer-cert   2026-01-10T15:25:18Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-datadog-observer-cert   2026-01-10T15:25:12Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-dns-observer-cert   2026-01-10T15:24:56Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-docker-observer-cert   2026-01-10T15:24:39Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-dynatrace-observer-cert   2026-01-10T15:22:42Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-external-risks-observer-cert   2026-01-10T15:24:47Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-file-observer-cert   2026-01-10T15:25:07Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-gitlab-observer-cert   2026-01-10T15:25:08Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-googlecloud-observer-cert   2026-01-10T15:20:36Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-hpnfvd-observer-cert   2026-01-10T15:23:42Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ibmcloud-observer-cert   2026-01-10T15:23:39Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-instana-observer-cert   2026-01-10T15:25:08Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-inventory-cert   2026-01-10T15:21:42Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-itnm-observer-cert   2026-01-10T15:24:46Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-jenkins-observer-cert   2026-01-10T15:22:38Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-junipercso-observer-cert   2026-01-10T15:21:11Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-kubernetes-observer-cert   2026-01-10T15:25:10Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-layout-cert   2026-01-10T15:19:03Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-topology-merge-cert   2026-01-10T15:19:04Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-newrelic-observer-cert   2026-01-10T15:20:22Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-observer-service-cert   2026-01-10T15:22:26Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-openstack-observer-cert   2026-01-10T15:23:04Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-client-cert   2025-12-22T11:14:26Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-server-cert   2025-12-22T11:15:08Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-rancher-observer-cert   2026-01-10T15:25:22Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-rest-observer-cert   2026-01-10T15:25:10Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-sdconap-observer-cert   2026-01-10T15:21:26Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-servicenow-observer-cert   2026-01-10T15:24:42Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-sevone-observer-cert   2026-01-10T15:24:55Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-status-cert   2026-01-10T15:23:45Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-taddm-observer-cert   2026-01-10T15:25:10Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-topology-topology-cert   2026-01-10T15:24:16Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-ui-api-cert   2026-01-10T15:25:25Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-viptela-observer-cert   2026-01-10T15:21:31Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmvcenter-observer-cert   2026-01-10T15:24:42Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmwarensx-observer-cert   2026-01-10T15:24:56Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-zabbix-observer-cert   2026-01-10T15:24:41Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ui-tls-certificate   2025-12-22T11:45:51Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2027-09-23T11:15:24Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-generic-topology-cert-311f6403   2025-12-22T11:22:34Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-im-topology-inte-cert-3af45ef1   2025-12-22T11:20:14Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2027-09-23T11:15:08Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2025-12-22T11:11:28Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2025-12-22T11:12:48Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2025-12-22T11:12:06Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2026-09-23T11:12:07Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2025-12-22T11:12:54Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2026-07-28T11:12:57Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-61045fad   2027-02-22T03:18:02Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
connector-manager-cert-94f55ac3   2025-12-22T11:18:14Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
connector-orchestrator-cert-78275888   2025-12-22T11:17:58Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
cp4waiops-connectors-deploy   2025-12-22T11:15:18Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2027-02-22T03:10:47Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
flink-operator-cert   2025-12-22T11:10:43Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2025-12-22T11:32:23Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2026-07-28T11:13:30Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2025-12-22T11:24:56Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2025-12-22T11:24:16Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2025-12-22T11:21:55Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2026-07-28T11:15:36Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2026-07-28T11:13:33Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2026-07-28T11:13:25Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2032-06-21T19:52:38Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2032-06-21T19:52:12Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2032-06-21T19:52:17Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
watsonx-ai-controller-cert-ef939d2b   2025-12-22T11:24:15Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
whconn-276002f0-a901-44c0--cert-eaba0861   2025-12-22T11:24:39Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2025-12-22T11:25:30Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2026-09-23T11:24:09Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2026-10-23T11:26:17Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

katamari                                           operand-deployment-lifecycle-manager-657bb6db5f-tpnwp                     1/1     Running      0              141m
______________________________________________________________
Orchestrator pod current status:

katamari                                           ibm-aiops-orchestrator-controller-manager-57b9677cc9-m8n6m                1/1     Running      0              145m

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
oc waiops status <namespace>
oc waiops status-all <namespace>
oc waiops status-upgrade <namespace>
```
