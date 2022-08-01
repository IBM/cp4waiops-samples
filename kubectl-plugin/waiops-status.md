# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
Run `oc waiops status` to print the statuses of some of your instance's main components. If you see components with issues (or are generally facing issues on your cluster), run `oc waiops status-all` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status`)
```
$ oc waiops status

Cloud Pak for Watson AIOps AI Manager v3.4 installation status:
______________________________________________________________
INSTALLATION INSTANCE

NAME                  PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
ibm-cp-watson-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          28h

______________________________________________________________
FOUNDATIONAL COMPONENTS

Commonservice instance:

KIND            NAMESPACE             NAME             STATUS
CommonService   ibm-common-services   common-service   Succeeded

ZenService instance:

KIND         NAMESPACE   NAME                 VERSION   STATUS      PROGRESS   MESSAGE
ZenService   cp4waiops   iaf-zen-cpdservice   4.5.0     Completed   100%       The Current Operation Is Completed

IAF instances:

KIND                 NAMESPACE   NAME         VERSION   STATUS   MESSAGE
AutomationUIConfig   cp4waiops   iaf-system   1.3.5     True     AutomationUIConfig successfully registered

KIND             NAMESPACE   NAME                    VERSION   STATUS   MESSAGE
AutomationBase   cp4waiops   automationbase-sample   2.0.5     True     AutomationBase instance successfully created

KIND        NAMESPACE   NAME                  VERSION   STATUS   MESSAGE
Cartridge   cp4waiops   cp4waiops-cartridge   1.3.5     True     Cartridge successfully registered

KIND                    NAMESPACE   NAME                  VERSION   STATUS   MESSAGE
CartridgeRequirements   cp4waiops   cp4waiops-cartridge   1.3.5     True     CartridgeRequirements successfully registered

Database instances:

KIND             NAMESPACE   NAME                 VERSION   STATUS   MESSAGE
EventProcessor   cp4waiops   aiops-ir-lifecycle   3.0.0     True     Event Processor is ready

KIND             NAMESPACE   NAME                       VERSION   STATUS   MESSAGE
EventProcessor   cp4waiops   cp4waiops-eventprocessor   4.0.7     True     Event Processor is ready

KIND            NAMESPACE   NAME         READY
Elasticsearch   cp4waiops   iaf-system   True

KIND    NAMESPACE   NAME         READY
Kafka   cp4waiops   iaf-system   True

KIND         NAMESPACE   NAME                   VERSION   STATUS   MESSAGE
PostgresDB   cp4waiops   cp4waiops-postgresdb   1.0.0     True     Success to create postgres db

KIND      NAMESPACE   NAME                               READY
Cluster   cp4waiops   ibm-cp-watson-aiops-edb-postgres   Cluster in healthy state

KIND        NAMESPACE   NAME            READY
Formation   cp4waiops   example-redis   OK

KIND        NAMESPACE   NAME                     READY
Formation   cp4waiops   example-couchdbcluster   OK

______________________________________________________________
CP4WAIOPS COMPONENTS

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4waiops   baseui-instance   3.4.0     True     Ready

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4waiops   aimanager   2.5.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.7.0     OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4waiops   aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4waiops   aiopsui-instance   3.4.0     True     Ready

______________________________________________________________

Hint: for a more detailed printout of component statuses, run `oc waiops status-all`.

```

### Detailed installation status checker output (`oc waiops status-all`)
```
$ oc waiops status-all

Cloud Pak for Watson AIOps AI Manager v3.4 installation status:
______________________________________________________________
Installation instances:

NAME                  PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
ibm-cp-watson-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          28h

______________________________________________________________
FOUNDATIONAL COMPONENTS

Commonservice instance:

KIND            NAMESPACE             NAME             STATUS
CommonService   ibm-common-services   common-service   Succeeded

ZenService instance:

KIND         NAMESPACE   NAME                 VERSION   STATUS      PROGRESS   MESSAGE
ZenService   cp4waiops   iaf-zen-cpdservice   4.5.0     Completed   100%       The Current Operation Is Completed

IAF instances:

KIND                 NAMESPACE   NAME         VERSION   STATUS   MESSAGE
AutomationUIConfig   cp4waiops   iaf-system   1.3.5     True     AutomationUIConfig successfully registered

KIND             NAMESPACE   NAME                    VERSION   STATUS   MESSAGE
AutomationBase   cp4waiops   automationbase-sample   2.0.5     True     AutomationBase instance successfully created

KIND        NAMESPACE   NAME                  VERSION   STATUS   MESSAGE
Cartridge   cp4waiops   cp4waiops-cartridge   1.3.5     True     Cartridge successfully registered

KIND                    NAMESPACE   NAME                  VERSION   STATUS   MESSAGE
CartridgeRequirements   cp4waiops   cp4waiops-cartridge   1.3.5     True     CartridgeRequirements successfully registered

Database instances:

KIND             NAMESPACE   NAME                 VERSION   STATUS   MESSAGE
EventProcessor   cp4waiops   aiops-ir-lifecycle   3.0.0     True     Event Processor is ready

KIND             NAMESPACE   NAME                       VERSION   STATUS   MESSAGE
EventProcessor   cp4waiops   cp4waiops-eventprocessor   4.0.7     True     Event Processor is ready

KIND            NAMESPACE   NAME         READY
Elasticsearch   cp4waiops   iaf-system   True

KIND    NAMESPACE   NAME         READY
Kafka   cp4waiops   iaf-system   True

KIND         NAMESPACE   NAME                   VERSION   STATUS   MESSAGE
PostgresDB   cp4waiops   cp4waiops-postgresdb   1.0.0     True     Success to create postgres db

KIND      NAMESPACE   NAME                               READY
Cluster   cp4waiops   ibm-cp-watson-aiops-edb-postgres   Cluster in healthy state

KIND        NAMESPACE   NAME            READY
Formation   cp4waiops   example-redis   OK

KIND        NAMESPACE   NAME                     READY
Formation   cp4waiops   example-couchdbcluster   OK

______________________________________________________________
CP4WAIOPS COMPONENTS

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4waiops   aiops   3.4.0     Ready    All Services Ready

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4waiops   baseui-instance   3.4.0     True     Ready

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4waiops   aiopsui-instance   3.4.0     True     Ready

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4waiops   aimanager   2.5.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.7.0     OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4waiops   aiopsedge   Configured   all critical components are reporting healthy

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   cp4waiops   gateway   True     <none>

KIND          NAMESPACE   NAME               VERSION   STATUS   MESSAGE
VaultDeploy   cp4waiops   ibm-vault-deploy   3.4.0     True     VaultDeploy completed successfully

KIND          NAMESPACE   NAME               VERSION   STATUS   MESSAGE
VaultAccess   cp4waiops   ibm-vault-access   3.4.0     True     VaultAccess completed successfully

KIND             NAMESPACE   NAME                 VERSION   STATUS   MESSAGE
Postgreservice   cp4waiops   cp4waiops-postgres   1.0.0     True     Success to deploy postgres stolon cluster

KIND         NAMESPACE   NAME                   VERSION   STATUS   MESSAGE
PostgresDB   cp4waiops   cp4waiops-postgresdb   1.0.0     True     Success to create postgres db

KIND     NAMESPACE   NAME         STATUS
Tunnel   cp4waiops   sre-tunnel   True

______________________________________________________________
CSVs from cp4waiops namespace:

NAME                        DISPLAY                       VERSION   REPLACES   PHASE
aimanager-operator.v3.4.0   IBM Watson AIOps AI Manager   3.4.0                Succeeded

NAME                        DISPLAY                 VERSION   REPLACES   PHASE
aiopsedge-operator.v3.4.0   IBM Watson AIOps Edge   3.4.0                Succeeded

NAME                  DISPLAY                             VERSION   REPLACES   PHASE
asm-operator.v3.4.0   IBM Netcool Agile Service Manager   3.4.0                Succeeded

NAME                      DISPLAY                       VERSION   REPLACES                  PHASE
couchdb-operator.v2.2.1   Operator for Apache CouchDB   2.2.1     couchdb-operator.v2.2.0   Succeeded

NAME                     DISPLAY                                            VERSION   REPLACES   PHASE
ibm-aiops-ir-ai.v3.4.0   IBM Watson AIOps Issue Resolution AI & Analytics   3.4.0                Succeeded

NAME                       DISPLAY                                  VERSION   REPLACES   PHASE
ibm-aiops-ir-core.v3.4.0   IBM Watson AIOps Issue Resolution Core   3.4.0                Succeeded

NAME                            DISPLAY                                    VERSION   REPLACES   PHASE
ibm-aiops-ir-lifecycle.v3.4.0   IBM Cloud Pak for Watson AIOps Lifecycle   3.4.0                Succeeded

NAME                            DISPLAY                                     VERSION   REPLACES   PHASE
ibm-aiops-orchestrator.v3.4.0   IBM Cloud Pak for Watson AIOps AI Manager   3.4.0                Succeeded

NAME                         DISPLAY                          VERSION   REPLACES                     PHASE
ibm-automation-core.v1.3.7   IBM Automation Foundation Core   1.3.7     ibm-automation-core.v1.3.6   Succeeded

NAME                            DISPLAY       VERSION   REPLACES                        PHASE
ibm-automation-elastic.v1.3.6   IBM Elastic   1.3.6     ibm-automation-elastic.v1.3.5   Succeeded

NAME                                    DISPLAY                                      VERSION   REPLACES                                PHASE
ibm-automation-eventprocessing.v1.3.7   IBM Automation Foundation Event Processing   1.3.7     ibm-automation-eventprocessing.v1.3.6   Succeeded

NAME                          DISPLAY                           VERSION   REPLACES                      PHASE
ibm-automation-flink.v1.3.6   IBM Automation Foundation Flink   1.3.6     ibm-automation-flink.v1.3.5   Succeeded

NAME                    DISPLAY                     VERSION   REPLACES                PHASE
ibm-automation.v1.3.7   IBM Automation Foundation   1.3.7     ibm-automation.v1.3.6   Succeeded

NAME                               DISPLAY                  VERSION   REPLACES                           PHASE
ibm-cloud-databases-redis.v1.4.3   IBM Operator for Redis   1.4.3     ibm-cloud-databases-redis.v1.4.2   Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES                              PHASE
ibm-common-service-operator.v3.19.0   IBM Cloud Pak foundational services   3.19.0    ibm-common-service-operator.v3.18.0   Succeeded

NAME                         DISPLAY                                VERSION   REPLACES   PHASE
ibm-management-kong.v3.4.0   IBM Internal - IBM Watson AIOps Kong   3.4.0                Succeeded

NAME                                 DISPLAY              VERSION   REPLACES   PHASE
ibm-postgreservice-operator.v3.4.0   IBM Postgreservice   3.4.0                Succeeded

NAME                                DISPLAY             VERSION   REPLACES   PHASE
ibm-secure-tunnel-operator.v3.4.0   IBM Secure Tunnel   3.4.0                Succeeded

NAME                        DISPLAY              VERSION   REPLACES   PHASE
ibm-vault-operator.v3.4.0   IBM Vault Operator   3.4.0                Succeeded

NAME                                  DISPLAY               VERSION   REPLACES   PHASE
ibm-watson-aiops-ui-operator.v3.4.0   IBM Watson AIOps UI   3.4.0                Succeeded

______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                              DISPLAY                       VERSION   REPLACES                          PHASE
cloud-native-postgresql.v1.15.1   EDB Postgres for Kubernetes   1.15.1    cloud-native-postgresql.v1.15.0   Succeeded

NAME                                DISPLAY            VERSION   REPLACES                            PHASE
ibm-cert-manager-operator.v3.21.0   IBM Cert Manager   3.21.0    ibm-cert-manager-operator.v3.20.0   Succeeded

NAME                                  DISPLAY                               VERSION   REPLACES                              PHASE
ibm-common-service-operator.v3.19.0   IBM Cloud Pak foundational services   3.19.0    ibm-common-service-operator.v3.18.0   Succeeded

NAME                            DISPLAY         VERSION   REPLACES                        PHASE
ibm-commonui-operator.v1.17.0   Ibm Common UI   1.17.0    ibm-commonui-operator.v1.16.0   Succeeded

NAME                             DISPLAY          VERSION   REPLACES                         PHASE
ibm-crossplane-operator.v1.8.0   IBM Crossplane   1.8.0     ibm-crossplane-operator.v1.7.0   Succeeded

NAME                                                 DISPLAY                              VERSION   REPLACES                                             PHASE
ibm-crossplane-provider-kubernetes-operator.v1.8.0   IBM Crossplane Provider Kubernetes   1.8.0     ibm-crossplane-provider-kubernetes-operator.v1.7.0   Succeeded

NAME                         DISPLAY               VERSION   REPLACES                     PHASE
ibm-events-operator.v4.2.0   IBM Events Operator   4.2.0     ibm-events-operator.v4.0.0   Succeeded

NAME                       DISPLAY   VERSION   REPLACES                   PHASE
ibm-iam-operator.v3.19.0   IBM IAM   3.19.0    ibm-iam-operator.v3.18.0   Succeeded

NAME                                 DISPLAY                      VERSION   REPLACES                             PHASE
ibm-ingress-nginx-operator.v1.16.0   IBM Ingress Nginx Operator   1.16.0    ibm-ingress-nginx-operator.v1.15.0   Succeeded

NAME                             DISPLAY         VERSION   REPLACES                         PHASE
ibm-licensing-operator.v1.16.0   IBM Licensing   1.16.0    ibm-licensing-operator.v1.15.0   Succeeded

NAME                                      DISPLAY              VERSION   REPLACES                                  PHASE
ibm-management-ingress-operator.v1.16.0   Management Ingress   1.16.0    ibm-management-ingress-operator.v1.15.0   Succeeded

NAME                           DISPLAY                VERSION   REPLACES                       PHASE
ibm-mongodb-operator.v1.14.0   IBM MongoDB Operator   1.14.0    ibm-mongodb-operator.v1.13.0   Succeeded

NAME                                   DISPLAY                       VERSION   REPLACES                               PHASE
ibm-namespace-scope-operator.v1.13.0   IBM NamespaceScope Operator   1.13.0    ibm-namespace-scope-operator.v1.12.0   Succeeded

NAME                                DISPLAY            VERSION   REPLACES                            PHASE
ibm-platform-api-operator.v3.21.0   IBM Platform API   3.21.0    ibm-platform-api-operator.v3.20.0   Succeeded

NAME                      DISPLAY           VERSION   REPLACES                  PHASE
ibm-zen-operator.v1.6.0   IBM Zen Service   1.6.0     ibm-zen-operator.v1.5.0   Succeeded

NAME                                           DISPLAY                                VERSION   REPLACES                                       PHASE
operand-deployment-lifecycle-manager.v1.17.0   Operand Deployment Lifecycle Manager   1.17.0    operand-deployment-lifecycle-manager.v1.16.0   Succeeded

______________________________________________________________
Subscriptions from cp4waiops namespace:

NAME                 PACKAGE              SOURCE                 CHANNEL
aimanager-operator   aimanager-operator   ibm-operator-catalog   v3.4

NAME                 PACKAGE              SOURCE                 CHANNEL
aiopsedge-operator   aiopsedge-operator   ibm-operator-catalog   v3.4

NAME           PACKAGE        SOURCE                 CHANNEL
asm-operator   asm-operator   ibm-operator-catalog   v3.4

NAME      PACKAGE            SOURCE                 CHANNEL
couchdb   couchdb-operator   ibm-operator-catalog   v2.2

NAME                     PACKAGE                  SOURCE                 CHANNEL
ibm-aiops-orchestrator   ibm-aiops-orchestrator   ibm-operator-catalog   v3.4

NAME                                                             PACKAGE          SOURCE                 CHANNEL
ibm-automation-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation   ibm-operator-catalog   v1.3

NAME                                                                  PACKAGE               SOURCE                 CHANNEL
ibm-automation-core-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation-core   ibm-operator-catalog   v1.3

NAME                                                                     PACKAGE                  SOURCE                 CHANNEL
ibm-automation-elastic-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation-elastic   ibm-operator-catalog   v1.3

NAME                                                                             PACKAGE                          SOURCE                 CHANNEL
ibm-automation-eventprocessing-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation-eventprocessing   ibm-operator-catalog   v1.3

NAME                                                                   PACKAGE                SOURCE                 CHANNEL
ibm-automation-flink-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation-flink   ibm-operator-catalog   v1.3

NAME                                                                        PACKAGE                       SOURCE                 CHANNEL
ibm-common-service-operator-v3-ibm-operator-catalog-openshift-marketplace   ibm-common-service-operator   ibm-operator-catalog   v3

NAME                  PACKAGE               SOURCE                 CHANNEL
ibm-management-kong   ibm-management-kong   ibm-operator-catalog   v3.4

NAME                          PACKAGE                       SOURCE                 CHANNEL
ibm-postgreservice-operator   ibm-postgreservice-operator   ibm-operator-catalog   v3.4

NAME                         PACKAGE                      SOURCE                 CHANNEL
ibm-secure-tunnel-operator   ibm-secure-tunnel-operator   ibm-operator-catalog   v3.4

NAME                           PACKAGE                        SOURCE                 CHANNEL
ibm-watson-aiops-ui-operator   ibm-watson-aiops-ui-operator   ibm-operator-catalog   v3.4

NAME             PACKAGE           SOURCE                 CHANNEL
ir-ai-operator   ibm-aiops-ir-ai   ibm-operator-catalog   v3.4

NAME               PACKAGE             SOURCE                 CHANNEL
ir-core-operator   ibm-aiops-ir-core   ibm-operator-catalog   v3.4

NAME                    PACKAGE                  SOURCE                 CHANNEL
ir-lifecycle-operator   ibm-aiops-ir-lifecycle   ibm-operator-catalog   v3.4

NAME    PACKAGE                              SOURCE                 CHANNEL
redis   ibm-cloud-databases-redis-operator   ibm-operator-catalog   v1.4

NAME    PACKAGE              SOURCE                 CHANNEL
vault   ibm-vault-operator   ibm-operator-catalog   v3.4

______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                      PACKAGE                   SOURCE                 CHANNEL
cloud-native-postgresql   cloud-native-postgresql   ibm-operator-catalog   stable

NAME                        PACKAGE                     SOURCE                 CHANNEL
ibm-cert-manager-operator   ibm-cert-manager-operator   ibm-operator-catalog   v3

NAME                          PACKAGE                       SOURCE                 CHANNEL
ibm-common-service-operator   ibm-common-service-operator   ibm-operator-catalog   v3

NAME                    PACKAGE                     SOURCE                 CHANNEL
ibm-commonui-operator   ibm-commonui-operator-app   ibm-operator-catalog   v3

NAME                          PACKAGE                       SOURCE                 CHANNEL
ibm-crossplane-operator-app   ibm-crossplane-operator-app   ibm-operator-catalog   v3

NAME                                              PACKAGE                                           SOURCE                 CHANNEL
ibm-crossplane-provider-kubernetes-operator-app   ibm-crossplane-provider-kubernetes-operator-app   ibm-operator-catalog   v3

NAME                  PACKAGE               SOURCE                 CHANNEL
ibm-events-operator   ibm-events-operator   ibm-operator-catalog   v3

NAME               PACKAGE            SOURCE                 CHANNEL
ibm-iam-operator   ibm-iam-operator   ibm-operator-catalog   v3

NAME                         PACKAGE                          SOURCE                 CHANNEL
ibm-ingress-nginx-operator   ibm-ingress-nginx-operator-app   ibm-operator-catalog   v3

NAME                     PACKAGE                      SOURCE                 CHANNEL
ibm-licensing-operator   ibm-licensing-operator-app   ibm-operator-catalog   v3

NAME                              PACKAGE                               SOURCE                 CHANNEL
ibm-management-ingress-operator   ibm-management-ingress-operator-app   ibm-operator-catalog   v3

NAME                   PACKAGE                    SOURCE                 CHANNEL
ibm-mongodb-operator   ibm-mongodb-operator-app   ibm-operator-catalog   v3

NAME                           PACKAGE                        SOURCE                 CHANNEL
ibm-namespace-scope-operator   ibm-namespace-scope-operator   ibm-operator-catalog   v3

NAME                        PACKAGE                         SOURCE                 CHANNEL
ibm-platform-api-operator   ibm-platform-api-operator-app   ibm-operator-catalog   v3

NAME               PACKAGE            SOURCE                 CHANNEL
ibm-zen-operator   ibm-zen-operator   ibm-operator-catalog   v3

NAME                                       PACKAGE    SOURCE                 CHANNEL
operand-deployment-lifecycle-manager-app   ibm-odlm   ibm-operator-catalog   v3

______________________________________________________________
OperandRequest instances:

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   ibm-commonui-request   Running   2022-06-30T13:54:23Z

NAMESPACE             NAME              PHASE     CREATED AT
ibm-common-services   ibm-iam-request   Running   2022-06-30T13:54:23Z

NAMESPACE             NAME                  PHASE     CREATED AT
ibm-common-services   ibm-mongodb-request   Running   2022-06-30T13:56:03Z

NAMESPACE             NAME                 PHASE     CREATED AT
ibm-common-services   management-ingress   Running   2022-06-30T13:56:03Z

NAMESPACE             NAME                   PHASE     CREATED AT
ibm-common-services   platform-api-request   Running   2022-06-30T13:56:03Z

NAMESPACE   NAME             PHASE     CREATED AT
cp4waiops   aiopsedge-base   Running   2022-06-30T13:56:38Z

NAMESPACE   NAME           PHASE     CREATED AT
cp4waiops   aiopsedge-cs   Running   2022-06-30T13:56:38Z

NAMESPACE   NAME                PHASE     CREATED AT
cp4waiops   iaf-core-operator   Running   2022-06-30T13:32:05Z

NAMESPACE   NAME                           PHASE     CREATED AT
cp4waiops   iaf-eventprocessing-operator   Running   2022-06-30T13:32:01Z

NAMESPACE   NAME           PHASE     CREATED AT
cp4waiops   iaf-operator   Running   2022-06-30T13:32:02Z

NAMESPACE   NAME         PHASE     CREATED AT
cp4waiops   iaf-system   Running   2022-06-30T13:59:03Z

NAMESPACE   NAME                        PHASE     CREATED AT
cp4waiops   iaf-system-common-service   Running   2022-06-30T13:53:44Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4waiops   ibm-aiops-ai-manager   Running   2022-06-30T13:53:44Z

NAMESPACE   NAME                         PHASE     CREATED AT
cp4waiops   ibm-aiops-aiops-foundation   Running   2022-06-30T13:53:44Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4waiops   ibm-aiops-connection   Running   2022-06-30T13:53:44Z

NAMESPACE   NAME                   PHASE     CREATED AT
cp4waiops   ibm-elastic-operator   Running   2022-06-30T13:32:05Z

NAMESPACE   NAME              PHASE     CREATED AT
cp4waiops   ibm-iam-service   Running   2022-06-30T14:09:16Z

NAMESPACE   NAME                                  PHASE     CREATED AT
cp4waiops   operandrequest-kafkauser-iaf-system   Running   2022-06-30T14:22:00Z

______________________________________________________________
ODLM pod current status:

ibm-common-services                                operand-deployment-lifecycle-manager-7689f57598-hmxsc             1/1     Running     0          28h
______________________________________________________________
Orchestrator pod current status:

cp4waiops                                          ibm-aiops-orchestrator-controller-manager-57bb6b7d7d-9c48m        1/1     Running     0          28h

```

### Upgrade status checker (`oc waiops status-upgrade`):
```
$ oc waiops status-upgrade

______________________________________________________________

The following component(s) have finished upgrading:


KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4waiops   aiopsedge   Configured   all critical components are reporting healthy

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4waiops   aiops   3.3.0     Ready    All Services Ready

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4waiops   aiopsui-instance   3.3.0     True     Ready

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   cp4waiops   gateway   True     InstallSuccessful

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4waiops   aimanager   2.4.0     Completed   AI Manager is ready

KIND                  NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore   cp4waiops   aiops   3.3.0     Ready    All Services Ready

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.2.0     Ready    All Services Ready

KIND          NAMESPACE   NAME               VERSION   STATUS   MESSAGE
VaultDeploy   cp4waiops   ibm-vault-deploy   3.3.0     True     VaultDeploy completed successfully

KIND          NAMESPACE   NAME               VERSION   STATUS   MESSAGE
VaultAccess   cp4waiops   ibm-vault-access   3.3.0     True     VaultAccess completed successfully

KIND             NAMESPACE   NAME                   VERSION   STATUS   MESSAGE
Postgreservice   cp4waiops   cp4waiops-postgres     1.0.0     True     Success to deploy postgres stolon cluster
PostgresDB       cp4waiops   cp4waiops-postgresdb   1.0.0     True     Success to create postgres db

KIND     NAMESPACE   NAME         STATUS
Tunnel   katamari    sre-tunnel   True

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.5.0     OK

KIND             NAMESPACE   NAME                       VERSION   STATUS   MESSAGE
EventProcessor   cp4waiops   cp4waiops-eventprocessor   4.0.5     True     Event Processor is ready

______________________________________________________________

Hint: for a more detailed printout of each operator's components' statuses, run `oc waiops status` or `oc waiops status-all`.
```

## How to use

### Requirements
- You must have an installation of Cloud Pak for Watson AIOps AI Manager v3.3 or v3.4 on your cluster. 
- You must be logged into your cluster as a cluster admin. This is required for the tool to provide you a complete view of your install/upgrade status.

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
oc waiops status-all
oc waiops status-upgrade
```
