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
aiops-installation   Running   Accepted   rook-cephfs    rook-ceph-rbd            3h27m

______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4aiops    6.2.2     Completed   <none>     <none>

______________________________________________________________
Kafka and Elasticsearch instances:

KIND    NAMESPACE   NAME         STATUS
Kafka   cp4aiops    iaf-system   True

KIND      NAMESPACE   NAME               STATUS
Cluster   cp4aiops    aiops-opensearch   Available

______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4aiops    aiops   4.12.0    Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4aiops    aiops   4.12.0    Ready    All Services Ready

______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4aiops    aiops   4.12.0    Ready    All Services Ready

______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4aiops    baseui-instance   4.12.0    True     Ready

______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4aiops    aimanager   4.12.0    Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4aiops    aiops-topology   2.33.0    OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4aiops    aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4aiops    aiopsui-instance   4.12.0    True     Ready

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
aimanager-operator.v4.12.0-202512021245   IBM AIOps AI Manager   4.12.0-202512021245              Succeeded

NAME                                      DISPLAY          VERSION               REPLACES   PHASE
aiopsedge-operator.v4.12.0-202512021245   IBM AIOps Edge   4.12.0-202512021245              Succeeded

NAME                                DISPLAY                             VERSION               REPLACES   PHASE
asm-operator.v4.12.0-202512021245   IBM Netcool Agile Service Manager   4.12.0-202512021245              Succeeded

NAME                                   DISPLAY                                            VERSION               REPLACES   PHASE
ibm-aiops-ir-ai.v4.12.0-202512021245   IBM Watson AIOps Issue Resolution AI & Analytics   4.12.0-202512021245              Succeeded

NAME                                     DISPLAY                                  VERSION               REPLACES   PHASE
ibm-aiops-ir-core.v4.12.0-202512021245   IBM Watson AIOps Issue Resolution Core   4.12.0-202512021245              Succeeded

NAME                                          DISPLAY                                    VERSION               REPLACES   PHASE
ibm-aiops-ir-lifecycle.v4.12.0-202512021245   IBM Cloud Pak for Watson AIOps Lifecycle   4.12.0-202512021245              Succeeded

NAME                                          DISPLAY                   VERSION               REPLACES   PHASE
ibm-aiops-orchestrator.v4.12.0-202512021245   IBM Cloud Pak for AIOps   4.12.0-202512021245              Succeeded

NAME                                DISPLAY                   VERSION    REPLACES   PHASE
ibm-opensearch-operator.v1.1.4002   IBM Opensearch Operator   1.1.4002              Succeeded

NAME                            DISPLAY                          VERSION   REPLACES   PHASE
ibm-opencontent-flink.v2.0.14   IBM OpenContent Flink Operator   2.0.14               Succeeded

NAME                  DISPLAY                   VERSION   REPLACES   PHASE
ibm-redis-cp.v1.2.9   ibm-redis-cp-controller   1.2.9                Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES   PHASE
ibm-common-service-operator.v4.15.0   IBM Cloud Pak foundational services   4.15.0               Succeeded

NAME                                              DISPLAY             VERSION               REPLACES   PHASE
ibm-secure-tunnel-operator.v4.12.0-202512021245   IBM Secure Tunnel   4.12.0-202512021245              Succeeded

NAME                                                DISPLAY        VERSION               REPLACES   PHASE
ibm-watson-aiops-ui-operator.v4.12.0-202512021245   IBM AIOps UI   4.12.0-202512021245              Succeeded

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.25.3   EDB Postgres for Kubernetes   1.25.3    cloud-native-postgresql.v1.25.2   Succeeded

NAME                                DISPLAY            VERSION   REPLACES   PHASE
ibm-cert-manager-operator.v4.2.19   IBM Cert Manager   4.2.19               Succeeded

NAME                            DISPLAY         VERSION   REPLACES   PHASE
ibm-commonui-operator.v4.11.0   Ibm Common UI   4.11.0               Succeeded

NAME                         DISPLAY               VERSION   REPLACES   PHASE
ibm-events-operator.v5.2.1   IBM Events Operator   5.2.1                Succeeded

NAME                       DISPLAY           VERSION   REPLACES   PHASE
ibm-iam-operator.v4.14.0   IBM IM Operator   4.14.0               Succeeded

NAME                      DISPLAY           VERSION   REPLACES   PHASE
ibm-zen-operator.v6.2.2   IBM Zen Service   6.2.2                Succeeded

NAME                                          DISPLAY                                VERSION   REPLACES   PHASE
operand-deployment-lifecycle-manager.v4.5.3   Operand Deployment Lifecycle Manager   4.5.3                Succeeded

______________________________________________________________
Subscriptions from cp4aiops namespace:

NAME                 PACKAGE              SOURCE                  CHANNEL
aimanager-operator   aimanager-operator   ibm-cp-waiops-catalog   v4.12

NAME                 PACKAGE              SOURCE                  CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-cp-waiops-catalog   v4.12

NAME           PACKAGE        SOURCE                  CHANNEL
asm-operator   asm-operator   ibm-cp-waiops-catalog   v4.12

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-cp-waiops-catalog   v4.12

NAME                      PACKAGE                   SOURCE                  CHANNEL
ibm-opensearch-operator   ibm-opensearch-operator   ibm-cp-waiops-catalog   v1.1

NAME                    PACKAGE                 SOURCE                  CHANNEL
ibm-opencontent-flink   ibm-opencontent-flink   ibm-cp-waiops-catalog   v2.0

NAME                         PACKAGE                      SOURCE                  CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-cp-waiops-catalog   v4.12

NAME                           PACKAGE                        SOURCE                  CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-cp-waiops-catalog   v4.12

NAME              PACKAGE           SOURCE                  CHANNEL
ibm-aiops-ir-ai   ibm-aiops-ir-ai   ibm-cp-waiops-catalog   v4.12

NAME                PACKAGE             SOURCE                  CHANNEL
ibm-aiops-ir-core   ibm-aiops-ir-core   ibm-cp-waiops-catalog   v4.12

NAME                     PACKAGE                  SOURCE                  CHANNEL
ibm-aiops-ir-lifecycle   ibm-aiops-ir-lifecycle   ibm-cp-waiops-catalog   v4.12

NAME           PACKAGE        SOURCE                  CHANNEL
ibm-redis-cp   ibm-redis-cp   ibm-cp-waiops-catalog   v1.2

NAME                      PACKAGE                   SOURCE                  CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-cp-waiops-catalog   stable-v1.25

NAME                        PACKAGE                     SOURCE                  CHANNEL
ibm-commonui-operator-app   ibm-commonui-operator-app   ibm-cp-waiops-catalog   v4.11

NAME                  PACKAGE               SOURCE                  CHANNEL
ibm-events-operator   ibm-events-operator   ibm-cp-waiops-catalog   v5.2

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-cp-waiops-catalog   v4.14

NAME               PACKAGE            SOURCE                  CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-cp-waiops-catalog   v6.2

NAME                                       PACKAGE    SOURCE                  CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-cp-waiops-catalog   v4.5

NAME                        PACKAGE                       SOURCE                  CHANNEL
aiops-ibm-common-services   ibm-common-service-operator   ibm-cp-waiops-catalog   v4.15

______________________________________________________________
OperandRequest instances:

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-ai-manager   Running   2025-12-02T13:12:57Z

NAMESPACE   NAME                         PHASE     CREATED AT
cp4aiops    ibm-aiops-aiops-foundation   Running   2025-12-02T13:12:57Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4aiops    ibm-aiops-connection   Running   2025-12-02T13:12:57Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-service   Running   2025-12-02T13:13:25Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4aiops    ibm-iam-request   Running   2025-12-02T13:12:43Z

______________________________________________________________
AIOps certificate status:

NAME                    RENEWAL                READY   MESSAGE
aimanager-certificate   2026-01-31T13:26:19Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-appconnect-ir-cert   2026-01-31T13:14:54Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-client-cert   2026-01-31T13:10:01Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-installation-redis-server-cert   2026-01-31T13:10:02Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-installation-tls-ca   2026-01-31T13:09:47Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-classifier   2026-01-31T13:32:16Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-api   2026-01-31T13:32:33Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-metric-spark   2026-01-31T13:32:24Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-client-cert   2026-01-31T13:15:45Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-ir-analytics-postgres-server-cert   2026-01-31T13:15:39Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-ir-analytics-probablecause   2026-01-31T13:25:02Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-master   2026-01-31T13:32:33Z   True    Certificate is up to date and has not expired

NAME                                         RENEWAL                READY   MESSAGE
aiops-ir-analytics-spark-pipeline-composer   2026-01-31T13:32:30Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
aiops-ir-core-api   2026-01-31T13:30:26Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-archiving   2026-01-31T13:29:43Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-cem-users   2026-01-31T13:30:24Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-couchdb-api   2026-01-31T13:24:46Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-ir-core-esarchiving   2026-01-31T13:30:41Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncobackup   2026-01-31T13:27:18Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-api   2026-01-31T13:30:25Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-if   2026-01-31T13:30:25Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-jobmgr   2026-01-31T13:30:32Z   True    Certificate is up to date and has not expired

NAME                      RENEWAL                READY   MESSAGE
aiops-ir-core-ncodl-std   2026-01-31T13:30:39Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-core-ncoprimary   2026-01-31T13:25:20Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-client-cert   2026-01-31T13:15:58Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-ir-core-postgres-server-cert   2026-01-31T13:15:48Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-ir-core-rba-as   2026-01-31T13:30:15Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-rba-rbs   2026-01-31T13:30:22Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiops-ir-core-usercfg   2026-01-31T13:30:37Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink   2026-01-31T13:14:31Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-api   2026-01-31T13:14:34Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-flink-rest   2026-01-31T13:14:37Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-ir-lifecycle-policy-registry-svc   2026-01-31T13:15:11Z   True    Certificate is up to date and has not expired

NAME              RENEWAL                READY   MESSAGE
aiops-lad-flink   2026-01-31T13:13:11Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
aiops-lad-flink-api   2026-01-31T13:12:42Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-lad-flink-rest   2026-01-31T13:12:53Z   True    Certificate is up to date and has not expired

NAME                   RENEWAL                READY   MESSAGE
aiops-opensearch-tls   2026-01-31T13:13:09Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-client-cert   2026-01-31T13:12:31Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-orchestrator-postgres-server-cert   2026-01-31T13:12:37Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
aiops-topology-aaionap-cert   2026-02-19T17:21:48Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-alm-observer-cert   2026-02-19T17:21:44Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-ansibleawx-observer-cert   2026-02-19T17:21:33Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-appdynamics-observer-cert   2026-02-19T17:21:31Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-aws-observer-cert   2026-02-19T17:21:54Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-azure-observer-cert   2026-02-19T17:22:14Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-bigcloudfabric-observer-cert   2026-02-19T17:18:12Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-bigfixinventory-observer-cert   2026-02-19T17:21:13Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-cassandra-cert   2032-07-31T21:22:03Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
aiops-topology-cienablueplanet-observer-cert   2026-02-19T17:21:20Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ciscoaci-observer-cert   2026-02-19T17:21:18Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-contrail-observer-cert   2026-02-19T17:21:15Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-datadog-observer-cert   2026-02-19T17:19:05Z   True    Certificate is up to date and has not expired

NAME                               RENEWAL                READY   MESSAGE
aiops-topology-dns-observer-cert   2026-02-19T17:20:48Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-docker-observer-cert   2026-02-19T17:18:37Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-dynatrace-observer-cert   2026-02-19T17:22:02Z   True    Certificate is up to date and has not expired

NAME                                          RENEWAL                READY   MESSAGE
aiops-topology-external-risks-observer-cert   2026-02-19T17:22:00Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-file-observer-cert   2026-02-19T17:22:06Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-gitlab-observer-cert   2026-02-19T17:18:41Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiops-topology-googlecloud-observer-cert   2026-02-19T17:21:45Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-hpnfvd-observer-cert   2026-02-19T17:21:51Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-ibmcloud-observer-cert   2026-02-19T17:21:54Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-instana-observer-cert   2026-02-19T17:19:07Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
aiops-topology-inventory-cert   2026-02-19T17:22:18Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-itnm-observer-cert   2026-02-19T17:18:21Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-jenkins-observer-cert   2026-02-19T17:22:14Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-junipercso-observer-cert   2026-02-19T17:22:02Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-kubernetes-observer-cert   2026-02-19T17:22:07Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-layout-cert   2026-02-19T17:18:44Z   True    Certificate is up to date and has not expired

NAME                        RENEWAL                READY   MESSAGE
aiops-topology-merge-cert   2026-02-19T17:20:27Z   True    Certificate is up to date and has not expired

NAME                                    RENEWAL                READY   MESSAGE
aiops-topology-newrelic-observer-cert   2026-02-19T17:21:58Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-observer-service-cert   2026-02-19T17:20:24Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-openstack-observer-cert   2026-02-19T17:21:56Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-client-cert   2026-01-31T13:15:24Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-postgres-server-cert   2026-01-31T13:15:39Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-rancher-observer-cert   2026-02-19T17:18:09Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
aiops-topology-rest-observer-cert   2026-02-19T17:22:03Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-sdconap-observer-cert   2026-02-19T17:21:50Z   True    Certificate is up to date and has not expired

NAME                                      RENEWAL                READY   MESSAGE
aiops-topology-servicenow-observer-cert   2026-02-19T17:18:01Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-sevone-observer-cert   2026-02-19T17:19:31Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-status-cert   2026-02-19T17:21:50Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
aiops-topology-taddm-observer-cert   2026-02-19T17:21:56Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
aiops-topology-topology-cert   2026-02-19T17:21:46Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
aiops-topology-ui-api-cert   2026-02-19T17:22:12Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
aiops-topology-viptela-observer-cert   2026-02-19T17:20:33Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmvcenter-observer-cert   2026-02-19T17:20:00Z   True    Certificate is up to date and has not expired

NAME                                     RENEWAL                READY   MESSAGE
aiops-topology-vmwarensx-observer-cert   2026-02-19T17:21:50Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
aiops-topology-zabbix-observer-cert   2026-02-19T17:21:46Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
aiops-ui-tls-certificate   2026-01-31T13:25:49Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
aiopsedge-client-cert   2027-11-02T13:15:54Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-generic-topology-cert-bea10cd8   2026-01-31T13:16:51Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
aiopsedge-im-topology-inte-cert-a7727b46   2026-01-31T13:16:43Z   True    Certificate is up to date and has not expired

NAME          RENEWAL                READY   MESSAGE
aiopsedgeca   2027-11-02T13:15:53Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
appd-conn-16bfa074-4371-4e-cert-0b7f08ec   2026-01-31T14:36:41Z   True    Certificate is up to date and has not expired

NAME                                            RENEWAL                READY   MESSAGE
automationbase-sample-automationbase-ab-ss-ca   2026-01-31T13:12:24Z   True    Certificate is up to date and has not expired

NAME                            RENEWAL                READY   MESSAGE
common-service-db-im-tls-cert   2026-01-31T13:12:59Z   True    Certificate is up to date and has not expired

NAME                                 RENEWAL                READY   MESSAGE
common-service-db-replica-tls-cert   2026-01-31T13:12:56Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
common-service-db-tls-cert   2026-11-02T13:13:01Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
common-service-db-zen-tls-cert   2026-01-31T13:13:10Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
common-web-ui-ca-cert   2026-09-06T13:13:38Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
connector-bridge-cert-bd77c571   2027-04-03T05:16:23Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
connector-manager-cert-309dff39   2026-01-31T13:16:34Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
connector-orchestrator-cert-34c3415f   2026-01-31T13:16:50Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
cp4waiops-connectors-deploy   2026-01-31T13:15:23Z   True    Certificate is up to date and has not expired

NAME                RENEWAL                READY   MESSAGE
cs-ca-certificate   2027-04-03T05:12:07Z   True    Certificate is up to date and has not expired

NAME                  RENEWAL                READY   MESSAGE
flink-operator-cert   2026-01-31T13:11:44Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
ibm-custom-logs-conn-d32b3-cert-535a16b1   2026-01-31T14:39:42Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
ibm-zen-metastore-edb-certificate   2026-01-31T13:16:53Z   True    Certificate is up to date and has not expired

NAME                     RENEWAL                READY   MESSAGE
identity-provider-cert   2026-09-06T13:16:29Z   True    Certificate is up to date and has not expired

NAME                       RENEWAL                READY   MESSAGE
internal-tls-certificate   2026-01-31T13:14:23Z   True    Certificate is up to date and has not expired

NAME                              RENEWAL                READY   MESSAGE
internal-tls-pkcs12-certificate   2026-01-31T13:14:03Z   True    Certificate is up to date and has not expired

NAME                             RENEWAL                READY   MESSAGE
internal-tls-pkcs8-certificate   2026-01-31T13:14:21Z   True    Certificate is up to date and has not expired

NAME                 RENEWAL                READY   MESSAGE
platform-auth-cert   2026-09-06T13:16:36Z   True    Certificate is up to date and has not expired

NAME                           RENEWAL                READY   MESSAGE
platform-identity-management   2026-09-06T13:16:25Z   True    Certificate is up to date and has not expired

NAME             RENEWAL                READY   MESSAGE
saml-auth-cert   2026-09-06T13:16:27Z   True    Certificate is up to date and has not expired

NAME                         RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-api-cert   2032-07-31T21:36:18Z   True    Certificate is up to date and has not expired

NAME                                RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-controller-cert   2032-07-31T21:36:23Z   True    Certificate is up to date and has not expired

NAME                          RENEWAL                READY   MESSAGE
sre-tunnel-tunnel-ui-secret   2032-07-31T21:36:23Z   True    Certificate is up to date and has not expired

NAME                                  RENEWAL                READY   MESSAGE
watsonx-ai-controller-cert-fd5abdbc   2026-01-31T13:16:41Z   True    Certificate is up to date and has not expired

NAME                                       RENEWAL                READY   MESSAGE
whconn-6d7997f4-3cdf-42be--cert-4a19e0ae   2026-01-31T13:22:20Z   True    Certificate is up to date and has not expired

NAME                                           RENEWAL                READY   MESSAGE
zen-metastore-edb-replica-client-certificate   2026-01-31T13:14:16Z   True    Certificate is up to date and has not expired

NAME                                   RENEWAL                READY   MESSAGE
zen-metastore-edb-server-certificate   2026-11-02T13:14:12Z   True    Certificate is up to date and has not expired

NAME                    RENEWAL                READY   MESSAGE
zen-minio-certificate   2026-12-02T13:16:03Z   True    Certificate is up to date and has not expired

______________________________________________________________
ODLM pod current status:

cp4aiops                                           operand-deployment-lifecycle-manager-64dccfd4fc-wjcf5                     1/1     Running     0               3h29m
______________________________________________________________
Orchestrator pod current status:

cp4aiops                                           ibm-aiops-orchestrator-controller-manager-7646584475-pfk5d                1/1     Running     0               3h32m

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
