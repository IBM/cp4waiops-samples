# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights
Run `oc waiops status` to print out the status of some of your instance's main components. You can also run `oc waiops status-all` for a more detailed printout with more components.

If you are upgrading your instance to the latest version, run `oc waiops status-upgrade`, which returns a list of components that have (and have not) completed upgrading. 

Below are example outputs of these commands.

### Installation status checker output (`oc waiops status`)
```
$ oc waiops status

______________________________________________________________
Installation instances:

NAMESPACE   NAME                  PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
cp4waiops   ibm-cp-watson-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          63m
______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4waiops   4.4.2     Completed   100%       The Current Operation Is Completed
______________________________________________________________
AutomationUIConfig, AutomationBase, Cartridge, and CartridgeRequirements instances:

KIND                    NAMESPACE   NAME                    VERSION   STATUS   MESSAGE
AutomationUIConfig      cp4waiops   iaf-system              1.3.3     True     AutomationUIConfig successfully registered
AutomationBase          cp4waiops   automationbase-sample   2.0.3     True     AutomationBase instance successfully created
Cartridge               cp4waiops   cp4waiops-cartridge     1.3.3     True     Cartridge successfully registered
CartridgeRequirements   cp4waiops   cp4waiops-cartridge     1.3.3     True     CartridgeRequirements successfully registered
______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore          cp4waiops   aiops   3.3.0     Ready    All Services Ready
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.2.0     Ready    All Services Ready
______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4waiops   aiops   3.3.0     Ready    All Services Ready
______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4waiops   baseui-instance   3.3.0     True     Ready
______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4waiops   aimanager   2.4.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.5.0     OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4waiops   aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4waiops   aiopsui-instance   3.3.0     True     Ready

Hint: for a more detailed printout of each operator's components' statuses, run `oc waiops status-all`.
```

### Detailed installation status checker output (`oc waiops status-all`)
```
$ oc waiops status

______________________________________________________________
Installation instances:

NAMESPACE   NAME                  PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
cp4waiops   ibm-cp-watson-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          63m
______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4waiops   4.4.2     Completed   100%       The Current Operation Is Completed
______________________________________________________________
AutomationUIConfig, AutomationBase, Cartridge, and CartridgeRequirements instances:

KIND                    NAMESPACE   NAME                    VERSION   STATUS   MESSAGE
AutomationUIConfig      cp4waiops   iaf-system              1.3.3     True     AutomationUIConfig successfully registered
AutomationBase          cp4waiops   automationbase-sample   2.0.3     True     AutomationBase instance successfully created
Cartridge               cp4waiops   cp4waiops-cartridge     1.3.3     True     Cartridge successfully registered
CartridgeRequirements   cp4waiops   cp4waiops-cartridge     1.3.3     True     CartridgeRequirements successfully registered
______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                         NAMESPACE   NAME    VERSION   STATUS   MESSAGE
IssueResolutionCore          cp4waiops   aiops   3.3.0     Ready    All Services Ready
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.2.0     Ready    All Services Ready
______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS   MESSAGE
LifecycleService   cp4waiops   aiops   3.3.0     Ready    All Services Ready
______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS   MESSAGE
BaseUI   cp4waiops   baseui-instance   3.3.0     True     Ready
______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME        VERSION   STATUS      MESSAGE
AIManager   cp4waiops   aimanager   2.4.0     Completed   AI Manager is ready

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.5.0     OK

KIND        NAMESPACE   NAME        STATUS       MESSAGE
AIOpsEdge   cp4waiops   aiopsedge   Configured   all critical components are reporting healthy

KIND      NAMESPACE   NAME               VERSION   STATUS   MESSAGE
AIOpsUI   cp4waiops   aiopsui-instance   3.3.0     True     Ready
______________________________________________________________
Kong instances:

KIND   NAMESPACE   NAME      STATUS   MESSAGE
Kong   cp4waiops   gateway   True     InstallSuccessful
______________________________________________________________
Vault (VaultDeploy and VaultAccess) instances:

KIND          NAMESPACE   NAME               VERSION   STATUS   MESSAGE
VaultDeploy   cp4waiops   ibm-vault-deploy   3.3.0     True     VaultDeploy completed successfully
VaultAccess   cp4waiops   ibm-vault-access   3.3.0     True     VaultAccess completed successfully
______________________________________________________________
Postgres (Postgreservices and PostgresDB) instances:

KIND             NAMESPACE   NAME                   VERSION   STATUS   MESSAGE
Postgreservice   cp4waiops   cp4waiops-postgres     1.0.0     True     Success to deploy postgres stolon cluster
PostgresDB       cp4waiops   cp4waiops-postgresdb   1.0.0     True     Success to create postgres db
______________________________________________________________
CSVs from cp4waiops namespace:

NAME                                    DISPLAY                                            VERSION   REPLACES                                PHASE
aimanager-operator.v3.3.0               IBM Watson AIOps AI Manager                        3.3.0                                             Succeeded
aiopsedge-operator.v3.3.0               IBM Watson AIOps Edge                              3.3.0                                             Succeeded
asm-operator.v3.3.0                     IBM Netcool Agile Service Manager                  3.3.0                                             Succeeded
couchdb-operator.v2.2.1                 Operator for Apache CouchDB                        2.2.1     couchdb-operator.v2.2.0                 Succeeded
ibm-aiops-ir-ai.v3.3.0                  IBM Watson AIOps Issue Resolution AI & Analytics   3.3.0                                             Succeeded
ibm-aiops-ir-core.v3.3.0                IBM Watson AIOps Issue Resolution Core             3.3.0                                             Succeeded
ibm-aiops-ir-lifecycle.v3.3.0           IBM Cloud Pak for Watson AIOps Lifecycle           3.3.0                                             Succeeded
ibm-aiops-orchestrator.v3.3.0           IBM Cloud Pak for Watson AIOps AI Manager          3.3.0                                             Succeeded
ibm-automation-core.v1.3.5              IBM Automation Foundation Core                     1.3.5     ibm-automation-core.v1.3.4              Succeeded
ibm-automation-elastic.v1.3.4           IBM Elastic                                        1.3.4     ibm-automation-elastic.v1.3.3           Succeeded
ibm-automation-eventprocessing.v1.3.5   IBM Automation Foundation Event Processing         1.3.5     ibm-automation-eventprocessing.v1.3.4   Succeeded
ibm-automation-flink.v1.3.4             IBM Automation Foundation Flink                    1.3.4     ibm-automation-flink.v1.3.3             Succeeded
ibm-automation.v1.3.5                   IBM Automation Foundation                          1.3.5     ibm-automation.v1.3.4                   Succeeded
ibm-cloud-databases-redis.v1.4.3        IBM Operator for Redis                             1.4.3     ibm-cloud-databases-redis.v1.4.2        Succeeded
ibm-common-service-operator.v3.16.3     IBM Cloud Pak foundational services                3.16.3    ibm-common-service-operator.v3.16.2     Succeeded
ibm-management-kong.v3.3.0              IBM Internal - IBM Watson AIOps Kong               3.3.0                                             Succeeded
ibm-postgreservice-operator.v3.3.0      IBM Postgreservice                                 3.3.0                                             Succeeded
ibm-vault-operator.v3.3.0               IBM Vault Operator                                 3.3.0                                             Succeeded
ibm-watson-aiops-ui-operator.v3.3.0     IBM Watson AIOps UI                                3.3.0                                             Succeeded
______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                                                 DISPLAY                                VERSION   REPLACES                                       PHASE
ibm-cert-manager-operator.v3.18.1                    IBM Cert Manager                       3.18.1    ibm-cert-manager-operator.v3.17.0              Succeeded
ibm-common-service-operator.v3.16.3                  IBM Cloud Pak foundational services    3.16.3    ibm-common-service-operator.v3.16.2            Succeeded
ibm-commonui-operator.v1.14.0                        Ibm Common UI                          1.14.0    ibm-commonui-operator.v1.13.0                  Succeeded
ibm-crossplane-operator.v1.5.0                       IBM Crossplane                         1.5.0     ibm-crossplane-operator.v1.4.1                 Succeeded
ibm-crossplane-provider-kubernetes-operator.v1.5.0   IBM Crossplane Provider Kubernetes     1.5.0                                                    Succeeded
ibm-events-operator.v3.15.0                          IBM Events Operator                    3.15.0    ibm-events-operator.v3.14.2                    Succeeded
ibm-iam-operator.v3.16.0                             IBM IAM Operator                       3.16.0    ibm-iam-operator.v3.13.0                       Succeeded
ibm-ingress-nginx-operator.v1.13.0                   IBM Ingress Nginx Operator             1.13.0    ibm-ingress-nginx-operator.v1.12.0             Succeeded
ibm-licensing-operator.v1.13.0                       IBM Licensing Operator                 1.13.0    ibm-licensing-operator.v1.12.0                 Succeeded
ibm-management-ingress-operator.v1.13.0              Management Ingress Operator            1.13.0    ibm-management-ingress-operator.v1.12.0        Succeeded
ibm-mongodb-operator.v1.11.0                         IBM MongoDB Operator                   1.11.0    ibm-mongodb-operator.v1.10.0                   Succeeded
ibm-namespace-scope-operator.v1.10.0                 IBM NamespaceScope Operator            1.10.0    ibm-namespace-scope-operator.v1.9.0            Succeeded
ibm-platform-api-operator.v3.18.0                    IBM Platform API                       3.18.0    ibm-platform-api-operator.v3.17.0              Succeeded
ibm-zen-operator.v1.5.2                              IBM Zen Service                        1.5.2     ibm-zen-operator.v1.5.1                        Succeeded
operand-deployment-lifecycle-manager.v1.14.1         Operand Deployment Lifecycle Manager   1.14.1    operand-deployment-lifecycle-manager.v1.14.0   Succeeded
______________________________________________________________
Subscriptions from cp4waiops namespace:

NAME                                                                             PACKAGE                              SOURCE                 CHANNEL
aimanager-operator                                                               aimanager-operator                   ibm-operator-catalog   v3.3
aiopsedge-operator                                                               aiopsedge-operator                   ibm-operator-catalog   v3.3
asm-operator                                                                     asm-operator                         ibm-operator-catalog   v3.3
couchdb                                                                          couchdb-operator                     ibm-operator-catalog   v2.2
ibm-aiops-orchestrator                                                           ibm-aiops-orchestrator               ibm-operator-catalog   v3.3
ibm-automation-core-v1.3-ibm-operator-catalog-openshift-marketplace              ibm-automation-core                  ibm-operator-catalog   v1.3
ibm-automation-elastic-v1.3-ibm-operator-catalog-openshift-marketplace           ibm-automation-elastic               ibm-operator-catalog   v1.3
ibm-automation-eventprocessing-v1.3-ibm-operator-catalog-openshift-marketplace   ibm-automation-eventprocessing       ibm-operator-catalog   v1.3
ibm-automation-flink-v1.3-ibm-operator-catalog-openshift-marketplace             ibm-automation-flink                 ibm-operator-catalog   v1.3
ibm-automation-v1.3-ibm-operator-catalog-openshift-marketplace                   ibm-automation                       ibm-operator-catalog   v1.3
ibm-common-service-operator-v3-ibm-operator-catalog-openshift-marketplace        ibm-common-service-operator          ibm-operator-catalog   v3
ibm-management-kong                                                              ibm-management-kong                  ibm-operator-catalog   v3.3
ibm-postgreservice-operator                                                      ibm-postgreservice-operator          ibm-operator-catalog   v3.3
ibm-watson-aiops-ui-operator                                                     ibm-watson-aiops-ui-operator         ibm-operator-catalog   v3.3
ir-ai-operator                                                                   ibm-aiops-ir-ai                      ibm-operator-catalog   v3.3
ir-core-operator                                                                 ibm-aiops-ir-core                    ibm-operator-catalog   v3.3
ir-lifecycle-operator                                                            ibm-aiops-ir-lifecycle               ibm-operator-catalog   v3.3
redis                                                                            ibm-cloud-databases-redis-operator   ibm-operator-catalog   v1.4
vault                                                                            ibm-vault-operator                   ibm-operator-catalog   v3.3
______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                                              PACKAGE                                           SOURCE                 CHANNEL
ibm-cert-manager-operator                         ibm-cert-manager-operator                         ibm-operator-catalog   v3
ibm-common-service-operator                       ibm-common-service-operator                       ibm-operator-catalog   v3
ibm-commonui-operator                             ibm-commonui-operator-app                         ibm-operator-catalog   v3
ibm-crossplane-operator-app                       ibm-crossplane-operator-app                       ibm-operator-catalog   v3
ibm-crossplane-provider-kubernetes-operator-app   ibm-crossplane-provider-kubernetes-operator-app   ibm-operator-catalog   v3
ibm-events-operator                               ibm-events-operator                               ibm-operator-catalog   v3
ibm-iam-operator                                  ibm-iam-operator                                  ibm-operator-catalog   v3
ibm-ingress-nginx-operator                        ibm-ingress-nginx-operator-app                    ibm-operator-catalog   v3
ibm-licensing-operator                            ibm-licensing-operator-app                        ibm-operator-catalog   v3
ibm-management-ingress-operator                   ibm-management-ingress-operator-app               ibm-operator-catalog   v3
ibm-mongodb-operator                              ibm-mongodb-operator-app                          ibm-operator-catalog   v3
ibm-namespace-scope-operator                      ibm-namespace-scope-operator                      ibm-operator-catalog   v3
ibm-platform-api-operator                         ibm-platform-api-operator-app                     ibm-operator-catalog   v3
ibm-zen-operator                                  ibm-zen-operator                                  ibm-operator-catalog   v3
operand-deployment-lifecycle-manager-app          ibm-odlm                                          ibm-operator-catalog   v3
______________________________________________________________
OperandRequest instances:

NAMESPACE             NAME                                  PHASE     CREATED AT
cp4waiops             aiopsedge-base                        Running   2022-04-13T00:46:20Z
cp4waiops             aiopsedge-cs                          Running   2022-04-13T00:46:20Z
cp4waiops             iaf-core-operator                     Running   2022-04-13T00:41:37Z
cp4waiops             iaf-eventprocessing-operator          Running   2022-04-13T00:41:34Z
cp4waiops             iaf-operator                          Running   2022-04-13T00:41:37Z
cp4waiops             iaf-system                            Running   2022-04-13T00:51:44Z
cp4waiops             iaf-system-common-service             Running   2022-04-13T00:44:07Z
cp4waiops             ibm-aiops-ai-manager                  Running   2022-04-13T00:44:03Z
cp4waiops             ibm-aiops-aiops-foundation            Running   2022-04-13T00:44:03Z
cp4waiops             ibm-aiops-application-manager         Running   2022-04-13T00:44:03Z
cp4waiops             ibm-elastic-operator                  Running   2022-04-13T00:41:37Z
cp4waiops             ibm-iam-service                       Running   2022-04-13T00:59:31Z
cp4waiops             operandrequest-kafkauser-iaf-system   Running   2022-04-13T01:07:19Z
ibm-common-services   ibm-commonui-request                  Running   2022-04-13T00:44:36Z
ibm-common-services   ibm-iam-request                       Running   2022-04-13T00:44:40Z
ibm-common-services   ibm-mongodb-request                   Running   2022-04-13T00:45:29Z
ibm-common-services   management-ingress                    Running   2022-04-13T00:45:29Z
ibm-common-services   platform-api-request                  Running   2022-04-13T00:45:29Z
______________________________________________________________
ODLM pod current status:

ibm-common-services                                operand-deployment-lifecycle-manager-dbd498fc5-brv57              1/1     Running       0          66m
______________________________________________________________
Orchestrator pod current status:

cp4waiops                                          ibm-aiops-orchestrator-controller-manager-cf876559-jvwz2          1/1     Running       0          64m
```

### Upgrade status checker (`oc waiops status-upgrade`):
```
$ oc waiops upgrade-status

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

KIND   NAMESPACE   NAME             VERSION   STATUS
ASM    cp4waiops   aiops-topology   2.5.0     OK

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
oc waiops status-all
oc waiops status-upgrade
```
