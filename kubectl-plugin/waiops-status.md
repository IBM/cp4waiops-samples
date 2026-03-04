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
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            150m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4aiops    6.4.0     Completed   <none>     <none>

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   cp4aiops    iaf-system   True

KIND      NAMESPACE   NAME               STATUS
Cluster   cp4aiops    aiops-opensearch   Available

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4aiops    aiops   4.13.0    Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4aiops    aiops   4.13.0    Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4aiops    aiops   4.13.0    <none>   All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4aiops    baseui-instance   4.13.0    True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4aiops    aimanager   4.13.0    Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4aiops    aiops-topology   2.34.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4aiops    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4aiops    aiopsui-instance   4.13.0    True     Ready

______________________________________________________________
Postgres instances:

KIND      NAMESPACE   NAME                          STATUS
Cluster   cp4aiops    aiops-ir-analytics-postgres   Cluster in healthy state
Cluster   cp4aiops    aiops-ir-core-postgres        Cluster in healthy state
Cluster   cp4aiops    aiops-orchestrator-postgres   Cluster in healthy state
Cluster   cp4aiops    aiops-topology-postgres       Cluster in healthy state
Cluster   cp4aiops    common-service-db             Cluster in healthy state
Cluster   cp4aiops    zen-metastore-edb             Cluster in healthy state

______________________________________________________________
Secure Tunnel instances:

KIND     NAMESPACE   NAME         STATUS
Tunnel   cp4aiops    sre-tunnel   True

______________________________________________________________
CSVs from cp4aiops namespace:

NAME                                      DISPLAY                VERSION               REPLACES   PHASE
aimanager-operator.v4.13.0-202603041045   IBM AIOps AI Manager   4.13.0-202603041045              Succeeded

NAME                                      DISPLAY          VERSION               REPLACES   PHASE
aiopsedge-operator.v4.13.0-202603041045   IBM AIOps Edge   4.13.0-202603041045              Succeeded

NAME                                DISPLAY                             VERSION               REPLACES   PHASE
asm-operator.v4.13.0-202603041045   IBM Netcool Agile Service Manager   4.13.0-202603041045              Succeeded

NAME                                   DISPLAY                                            VERSION               REPLACES   PHASE
ibm-aiops-ir-ai.v4.13.0-202603041045   IBM Watson AIOps Issue Resolution AI & Analytics   4.13.0-202603041045              Succeeded

NAME                                     DISPLAY                                  VERSION               REPLACES   PHASE
ibm-aiops-ir-core.v4.13.0-202603041045   IBM Watson AIOps Issue Resolution Core   4.13.0-202603041045              Succeeded

NAME                                          DISPLAY                                    VERSION               REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.13.0-202603041045   IBM Cloud Pak for Watson AIOps Lifecycle   4.13.0-202603041045              Succeeded

NAME                                          DISPLAY                   VERSION               REPLACES   PHASE
ibm-aiops-orchestrator.v4.13.0-202603041045   IBM Cloud Pak for AIOps   4.13.0-202603041045              Succeeded

NAME                             DISPLAY                   VERSION   REPLACES   PHASE
ibm-opensearch-operator.v1.2.0   IBM Opensearch Operator   1.2.0                Succeeded

NAME                            DISPLAY                          VERSION   REPLACES   PHASE
ibm-opencontent-flink.v2.0.17   IBM OpenContent Flink Operator   2.0.17               Succeeded

NAME                  DISPLAY                   VERSION   REPLACES   PHASE
ibm-redis-cp.v1.3.1   ibm-redis-cp-controller   1.3.1                Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.17.0   IBM Cloud Pak foundational services   4.17.0               Succeeded

NAME                                              DISPLAY             VERSION               REPLACES   PHASE
ibm-secure-tunnel-operator.v4.13.0-202603041045   IBM Secure Tunnel   4.13.0-202603041045              Succeeded

NAME                                                DISPLAY        VERSION               REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.13.0-202603041045   IBM AIOps UI   4.13.0-202603041045              Succeeded

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.25.5   EDB Postgres for Kubernetes   1.25.5    cloud-native-postgresql.v1.25.4   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.20   IBM Cert Manager   4.2.20               Succeeded

NAME                            DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.13.0   Ibm Common UI   4.13.0               Succeeded

NAME                         DISPLAY               VERSION   REPLACES                     PHASE
ibm-events-operator.v6.0.0   IBM Events Operator   6.0.0     ibm-events-operator.v5.2.1   Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.16.0   IBM IM Operator   4.16.0               Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v6.4.0   IBM Zen Service   6.4.0                Succeeded

NAME                                          DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.5.6   Operand Deployment Lifecycle Manager   4.5.6                Succeeded

______________________________________________________________
Subscriptions from cp4aiops namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.13

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.13

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.13

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.13

NAME                      PACKAGE                   SOURCE                  CHANNEL
ibm-opensearch-operator   ibm-opensearch-operator   ibm-cp-waiops-catalog   v1.1

NAME                    PACKAGE                 SOURCE                  CHANNEL
ibm-opencontent-flink   ibm-opencontent-flink   ibm-cp-waiops-catalog   v2.0

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.13

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.13

NAME              PACKAGE           SOURCE                  CHANNEL
ibm-aiops-ir-ai   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.13

NAME                PACKAGE             SOURCE                  CHANNEL
ibm-aiops-ir-core   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.13

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-ir-lifecycle   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.13

NAME           PACKAGE        SOURCE                  CHANNEL
ibm-redis-cp   ibm-redis-cp   ibm-cp-waiops-catalog   v1.3

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable-v1.25

NAME                        PACKAGE                     SOURCE                  CHANNEL
ibm-commonui-operator-app   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v4.13

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v6.0

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-cp-waiops-catalog   v4.16

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-cp-waiops-catalog   v6.4

NAME                                       PACKAGE    SOURCE                  CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-cp-waiops-catalog   v4.5

NAME                        PACKAGE                       SOURCE                  CHANNEL
aiops-ibm-common-services   ibm-common-service-operator   ibm-cp-waiops-catalog   v4.17

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-ai-manager   Running   2026-03-04T11:12:29Z

NAMESPACE   NAME                         PHASE     CREATED AT
cp4aiops    ibm-aiops-aiops-foundation   Running   2026-03-04T11:12:29Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-connection   Running   2026-03-04T11:12:29Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-service   Running   2026-03-04T11:13:09Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-request   Running   2026-03-04T11:12:04Z

______________________________________________________________
AIOps certificate status:

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2026-05-03T11:29:46Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-appconnect-ir-cert   2026-05-03T11:16:00Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2026-05-03T11:13:39Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2026-05-03T11:13:40Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-installation-tls-ca   2026-05-03T11:09:05Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-classifier   2026-05-03T11:36:56Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-api   2026-05-03T11:37:14Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-spark   2026-05-03T11:37:04Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-client-cert   2026-05-03T11:14:35Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-server-cert   2026-05-03T11:14:08Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-ir-analytics-probablecause   2026-05-03T11:24:31Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-master   2026-05-03T11:37:14Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-pipeline-composer   2026-05-03T11:37:07Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-ir-core-api   2026-05-03T11:35:32Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-archiving   2026-05-03T11:36:23Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-cem-users   2026-05-03T11:36:26Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-couchdb-api   2026-05-03T11:29:31Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-esarchiving   2026-05-03T11:36:25Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncobackup   2026-05-03T11:32:53Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-api   2026-05-03T11:36:26Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-if   2026-05-03T11:36:21Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr   2026-05-03T11:35:52Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr-umerge   2026-05-03T11:36:13Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr-umerge-kafka   2026-05-03T11:36:52Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-std   2026-05-03T11:36:19Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-core-ncoprimary   2026-05-03T11:31:21Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-client-cert   2026-05-03T11:15:23Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-server-cert   2026-05-03T11:15:13Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-ir-core-rba-as   2026-05-03T11:36:30Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-rba-rbs   2026-05-03T11:36:40Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-usercfg   2026-05-03T11:36:39Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink   2026-05-03T11:14:44Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-api   2026-05-03T11:15:31Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-rest   2026-05-03T11:14:49Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-zk-client   2026-05-03T11:15:04Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-policy-registry-svc   2026-05-03T11:14:31Z   True    Certificate is up to date and has not expired

NAME              RENEWAL                READY   MESSAGE
aiops-lad-flink   2026-05-03T11:12:28Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
aiops-lad-flink-api   2026-05-03T11:12:38Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-lad-flink-rest   2026-05-03T11:12:41Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-lad-flink-zk-client   2026-05-03T11:12:37Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-opensearch-tls   2026-05-03T11:12:43Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-client-cert   2026-05-03T11:12:07Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-server-cert   2026-05-03T11:12:27Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
aiops-topology-aaionap-cert   2026-05-22T15:18:32Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-alm-observer-cert   2026-05-22T15:21:06Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-ansibleawx-observer-cert   2026-05-22T15:18:21Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-appdynamics-observer-cert   2026-05-22T15:18:42Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-aws-observer-cert   2026-05-22T15:20:11Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-azure-observer-cert   2026-05-22T15:20:13Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-bigcloudfabric-observer-cert   2026-05-22T15:17:54Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-bigfixinventory-observer-cert   2026-05-22T15:19:32Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2032-10-31T19:21:14Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-cienablueplanet-observer-cert   2026-05-22T15:18:10Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ciscoaci-observer-cert   2026-05-22T15:21:21Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-contrail-observer-cert   2026-05-22T15:21:15Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-datadog-observer-cert   2026-05-22T15:20:56Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-dns-observer-cert   2026-05-22T15:18:30Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-docker-observer-cert   2026-05-22T15:20:53Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-dynatrace-observer-cert   2026-05-22T15:18:27Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-external-risks-observer-cert   2026-05-22T15:21:09Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-file-observer-cert   2026-05-22T15:20:02Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-gitlab-observer-cert   2026-05-22T15:21:25Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-googlecloud-observer-cert   2026-05-22T15:20:26Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-hpnfvd-observer-cert   2026-05-22T15:20:21Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ibmcloud-observer-cert   2026-05-22T15:19:13Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-instana-observer-cert   2026-05-22T15:18:04Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-inventory-cert   2026-05-22T15:17:41Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-itnm-observer-cert   2026-05-22T15:17:45Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-jenkins-observer-cert   2026-05-22T15:17:50Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-junipercso-observer-cert   2026-05-22T15:20:59Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-kubernetes-observer-cert   2026-05-22T15:17:33Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-layout-cert   2026-05-22T15:21:08Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-topology-merge-cert   2026-05-22T15:20:57Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-newrelic-observer-cert   2026-05-22T15:19:28Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-observer-service-cert   2026-05-22T15:17:09Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-openstack-observer-cert   2026-05-22T15:20:55Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-client-cert   2026-05-03T11:15:06Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-server-cert   2026-05-03T11:15:15Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-rancher-observer-cert   2026-05-22T15:20:56Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-rest-observer-cert   2026-05-22T15:21:03Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-sdconap-observer-cert   2026-05-22T15:18:45Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-servicenow-observer-cert   2026-05-22T15:20:16Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-sevone-observer-cert   2026-05-22T15:21:06Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-status-cert   2026-05-22T15:21:02Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-taddm-observer-cert   2026-05-22T15:21:03Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-topology-topology-cert   2026-05-22T15:18:35Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-ui-api-cert   2026-05-22T15:17:35Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-viptela-observer-cert   2026-05-22T15:17:19Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmvcenter-observer-cert   2026-05-22T15:20:28Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmwarensx-observer-cert   2026-05-22T15:20:18Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-zabbix-observer-cert   2026-05-22T15:21:34Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ui-tls-certificate   2026-05-03T11:29:00Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2028-02-02T11:16:08Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-generic-topology-cert-0d32cbf6   2026-05-03T11:17:24Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-im-topology-inte-cert-7d16b4c0   2026-05-03T11:20:52Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2028-02-02T11:15:32Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2026-05-03T11:12:00Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2026-05-03T11:12:24Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2026-05-03T11:12:28Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2027-02-02T11:12:22Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2026-05-03T11:12:48Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2026-12-07T11:13:14Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-626fc1c2   2027-07-04T03:16:12Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
connector-manager-cert-385c0fcd   2026-05-03T11:16:46Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
connector-orchestrator-cert-8a252c8e   2026-05-03T11:16:36Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
cp4waiops-connectors-deploy   2026-05-03T11:15:40Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2027-07-04T03:10:58Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
flink-operator-cert   2026-05-03T11:11:06Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2026-05-03T11:21:33Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2026-12-07T11:16:49Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2026-05-03T11:14:10Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2026-05-03T11:13:56Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2026-05-03T11:14:46Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2026-12-07T11:15:48Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2026-12-07T11:15:59Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2026-12-07T11:16:09Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2032-10-31T19:15:37Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2032-10-31T19:15:28Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2032-10-31T19:16:21Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
watsonx-ai-controller-cert-2ceec698   2026-05-03T11:19:50Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
whconn-59ff115e-43ad-481d--cert-404fbe5e   2026-05-03T11:21:31Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2026-05-03T11:14:45Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2027-02-02T11:15:37Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2027-03-04T11:16:37Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

cp4aiops                                           operand-deployment-lifecycle-manager-797bb86645-g95zn                     1/1     Running      0              153m
______________________________________________________________
Orchestrator pod current status:

cp4aiops                                           ibm-aiops-orchestrator-controller-manager-69474c494c-dkkjp                1/1     Running      0              157m

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
