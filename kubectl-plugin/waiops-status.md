# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights

```
$ oc waiops status
 __________________________________________________________
|                                                          |
|      CLOUD PAK FOR WATSON AIOPS STATUS CHECKER TOOL      |
|__________________________________________________________|
|  NOTE: Please remember to update the PROJECT_NAMESPACE   |
|  variable in the script so that it correctly references  |
|  your installation namespace.                            |
|                                                          |
|  If this is not set correctly, you will see errors in    |
|  the output of the status checker below.                 |
|                                                          |
|  PROJECT_NAMESPACE by default is set to "cp4waiops".     |
|                                                          |
|  If your install is in a namespace called "cp4waiops",   |
|  then no change to this script is required.              | 
|__________________________________________________________|

______________________________________________________________
Installation instances:

NAMESPACE   NAME                  PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
cp4waiops   ibm-cp-watson-aiops   Running   Accepted   rook-cephfs    rook-ceph-block          8d
______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                         NAMESPACE   NAME    VERSION   STATUS
IssueResolutionCore          cp4waiops   aiops   3.2.1     Ready
AIOpsAnalyticsOrchestrator   cp4waiops   aiops   3.2.0     Ready
______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS
LifecycleService   cp4waiops   aiops   3.3.0     Ready
______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS
BaseUI   cp4waiops   baseui-instance   3.3.0     Ready
______________________________________________________________
AIManager, AIOpsEdge, and ASM instances:

KIND        NAMESPACE   NAME             VERSION   STATUS
AIManager   cp4waiops   aimanager        2.4.0     Completed
AIOpsEdge   cp4waiops   aiopsedge        <none>    Configured
ASM         cp4waiops   aiops-topology   2.2.0     OK
______________________________________________________________
AutomationUIConfig, AutomationBase, Cartridge, and CartridgeRequirements instances:

KIND                    NAMESPACE   NAME                    VERSION   STATUS
AutomationUIConfig      cp4waiops   iaf-system              v1.3      True
AutomationBase          cp4waiops   automationbase-sample   v2.0      True
Cartridge               cp4waiops   cp4waiops-cartridge     v1.3      True
CartridgeRequirements   cp4waiops   cp4waiops-cartridge     v1.3      True
______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS      PROGRESS   MESSAGE
ZenService   iaf-zen-cpdservice   cp4waiops   4.4.1     Completed   100%       The Current Operation Is Completed
______________________________________________________________
CSVs from cp4waiops namespace:

NAME                                               DISPLAY                                            VERSION              REPLACES                                PHASE
aimanager-operator.v3.3.0-202203130801             IBM Watson AIOps AI Manager                        3.3.0-202203130801   aimanager-operator.v3.2.1               Succeeded
aiopsedge-operator.v3.3.0-202203130801             IBM Watson AIOps Edge                              3.3.0-202203130801   aiopsedge-operator.v3.2.1               Succeeded
asm-operator.v3.3.0-202203130801                   IBM Netcool Agile Service Manager                  3.3.0-202203130801   asm-operator.v3.2.1                     Succeeded
couchdb-operator.v2.2.1                            Operator for Apache CouchDB                        2.2.1                couchdb-operator.v2.2.0                 Succeeded
ibm-aiops-ir-ai.v3.3.0-202203130801                IBM Watson AIOps Issue Resolution AI & Analytics   3.3.0-202203130801   ibm-aiops-ir-ai.v3.2.1                  Succeeded
ibm-aiops-ir-core.v3.3.0-202203130801              IBM Watson AIOps Issue Resolution Core             3.3.0-202203130801   ibm-aiops-ir-core.v3.2.1                Succeeded
ibm-aiops-ir-lifecycle.v3.3.0-202203130801         IBM Cloud Pak for Watson AIOps Lifecycle           3.3.0-202203130801   ibm-aiops-ir-lifecycle.v3.2.1           Succeeded
ibm-aiops-orchestrator.v3.3.0-202203130801         IBM Cloud Pak for Watson AIOps AI Manager          3.3.0-202203130801   ibm-aiops-orchestrator.v3.2.1           Succeeded
ibm-automation-core.v1.3.4                         IBM Automation Foundation Core                     1.3.4                ibm-automation-core.v1.3.3              Succeeded
ibm-automation-elastic.v1.3.3                      IBM Elastic                                        1.3.3                ibm-automation-elastic.v1.3.2           Succeeded
ibm-automation-eventprocessing.v1.3.4              IBM Automation Foundation Event Processing         1.3.4                ibm-automation-eventprocessing.v1.3.3   Succeeded
ibm-automation-flink.v1.3.3                        IBM Automation Foundation Flink                    1.3.3                ibm-automation-flink.v1.3.2             Succeeded
ibm-automation.v1.3.4                              IBM Automation Foundation                          1.3.4                ibm-automation.v1.3.3                   Succeeded
ibm-cloud-databases-redis.v1.4.3                   IBM Operator for Redis                             1.4.3                ibm-cloud-databases-redis.v1.3.3        Succeeded
ibm-common-service-operator.v3.16.1                IBM Cloud Pak foundational services                3.16.1               ibm-common-service-operator.v3.15.1     Succeeded
ibm-management-kong.v3.3.0-202203130801            IBM Internal - IBM Watson AIOps Kong               3.3.0-202203130801   ibm-management-kong.v3.2.1              Succeeded
ibm-postgreservice-operator.v3.3.0-202203130801    IBM Postgreservice                                 3.3.0-202203130801   ibm-postgreservice-operator.v3.2.1      Succeeded
ibm-vault-operator.v3.3.0-202203130801             IBM Vault Operator                                 3.3.0-202203130801   ibm-vault-operator.v3.2.1               Succeeded
ibm-watson-aiops-ui-operator.v3.3.0-202203130801   IBM Watson AIOps UI                                3.3.0-202203130801   ibm-watson-aiops-ui-operator.v3.2.1     Succeeded
______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                                                 DISPLAY                                VERSION   REPLACES                                       PHASE
ibm-cert-manager-operator.v3.18.1                    IBM Cert Manager                       3.18.1    ibm-cert-manager-operator.v3.17.0              Succeeded
ibm-common-service-operator.v3.16.1                  IBM Cloud Pak foundational services    3.16.1    ibm-common-service-operator.v3.15.1            Succeeded
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
ibm-zen-operator.v1.5.1                              IBM Zen Service                        1.5.1     ibm-zen-operator.v1.5.0                        Succeeded
operand-deployment-lifecycle-manager.v1.14.0         Operand Deployment Lifecycle Manager   1.14.0    operand-deployment-lifecycle-manager.v1.13.0   Succeeded
______________________________________________________________
Subscriptions from cp4waiops namespace:

NAME                                                                              PACKAGE                              SOURCE                  CHANNEL
aimanager-operator                                                                aimanager-operator                   ibm-cp-waiops-catalog   3.3-dev
aiopsedge-operator                                                                aiopsedge-operator                   ibm-cp-waiops-catalog   3.3-dev
asm-operator                                                                      asm-operator                         ibm-cp-waiops-catalog   3.3-dev
couchdb                                                                           couchdb-operator                     ibm-cp-waiops-catalog   v2.2
ibm-aiops-orchestrator                                                            ibm-aiops-orchestrator               ibm-cp-waiops-catalog   3.3-dev
ibm-automation-core-v1.3-ibm-cp-waiops-catalog-openshift-marketplace              ibm-automation-core                  ibm-cp-waiops-catalog   v1.3
ibm-automation-elastic-v1.3-ibm-cp-waiops-catalog-openshift-marketplace           ibm-automation-elastic               ibm-cp-waiops-catalog   v1.3
ibm-automation-eventprocessing-v1.3-ibm-cp-waiops-catalog-openshift-marketplace   ibm-automation-eventprocessing       ibm-cp-waiops-catalog   v1.3
ibm-automation-flink-v1.3-ibm-cp-waiops-catalog-openshift-marketplace             ibm-automation-flink                 ibm-cp-waiops-catalog   v1.3
ibm-automation-v1.3-ibm-cp-waiops-catalog-openshift-marketplace                   ibm-automation                       ibm-cp-waiops-catalog   v1.3
ibm-common-service-operator-v3-ibm-cp-waiops-catalog-openshift-marketplace        ibm-common-service-operator          ibm-cp-waiops-catalog   v3
ibm-management-kong                                                               ibm-management-kong                  ibm-cp-waiops-catalog   3.3-dev
ibm-postgreservice-operator                                                       ibm-postgreservice-operator          ibm-cp-waiops-catalog   3.3-dev
ibm-watson-aiops-ui-operator                                                      ibm-watson-aiops-ui-operator         ibm-cp-waiops-catalog   3.3-dev
ir-ai-operator                                                                    ibm-aiops-ir-ai                      ibm-cp-waiops-catalog   3.3-dev
ir-core-operator                                                                  ibm-aiops-ir-core                    ibm-cp-waiops-catalog   3.3-dev
ir-lifecycle-operator                                                             ibm-aiops-ir-lifecycle               ibm-cp-waiops-catalog   3.3-dev
redis                                                                             ibm-cloud-databases-redis-operator   ibm-cp-waiops-catalog   v1.4
vault                                                                             ibm-vault-operator                   ibm-cp-waiops-catalog   3.3-dev
______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                                              PACKAGE                                           SOURCE                  CHANNEL
ibm-cert-manager-operator                         ibm-cert-manager-operator                         ibm-cp-waiops-catalog   v3
ibm-common-service-operator                       ibm-common-service-operator                       ibm-cp-waiops-catalog   v3
ibm-commonui-operator                             ibm-commonui-operator-app                         ibm-cp-waiops-catalog   v3
ibm-crossplane-operator-app                       ibm-crossplane-operator-app                       ibm-cp-waiops-catalog   v3
ibm-crossplane-provider-kubernetes-operator-app   ibm-crossplane-provider-kubernetes-operator-app   ibm-cp-waiops-catalog   v3
ibm-events-operator                               ibm-events-operator                               ibm-cp-waiops-catalog   v3
ibm-iam-operator                                  ibm-iam-operator                                  ibm-cp-waiops-catalog   v3
ibm-ingress-nginx-operator                        ibm-ingress-nginx-operator-app                    ibm-cp-waiops-catalog   v3
ibm-licensing-operator                            ibm-licensing-operator-app                        ibm-cp-waiops-catalog   v3
ibm-management-ingress-operator                   ibm-management-ingress-operator-app               ibm-cp-waiops-catalog   v3
ibm-mongodb-operator                              ibm-mongodb-operator-app                          ibm-cp-waiops-catalog   v3
ibm-namespace-scope-operator                      ibm-namespace-scope-operator                      ibm-cp-waiops-catalog   v3
ibm-platform-api-operator                         ibm-platform-api-operator-app                     ibm-cp-waiops-catalog   v3
ibm-zen-operator                                  ibm-zen-operator                                  ibm-cp-waiops-catalog   v3
operand-deployment-lifecycle-manager-app          ibm-odlm                                          ibm-cp-waiops-catalog   v3
______________________________________________________________
OperandRequest instances:

NAMESPACE             NAME                                  PHASE     CREATED AT
cp4waiops             aiopsedge-base                        Running   2022-03-14T16:23:01Z
cp4waiops             aiopsedge-cs                          Running   2022-03-14T16:23:01Z
cp4waiops             iaf-core-operator                     Running   2022-03-14T15:58:24Z
cp4waiops             iaf-eventprocessing-operator          Running   2022-03-14T15:58:24Z
cp4waiops             iaf-operator                          Running   2022-03-14T15:58:25Z
cp4waiops             iaf-system                            Running   2022-03-14T17:45:55Z
cp4waiops             iaf-system-common-service             Running   2022-03-14T16:20:45Z
cp4waiops             iaf-system-events                     Running   2022-03-14T16:20:45Z
cp4waiops             ibm-aiops-ai-manager                  Running   2022-03-14T16:20:40Z
cp4waiops             ibm-aiops-aiops-foundation            Running   2022-03-14T16:20:40Z
cp4waiops             ibm-aiops-application-manager         Running   2022-03-14T16:20:40Z
cp4waiops             ibm-elastic-operator                  Running   2022-03-14T15:58:24Z
cp4waiops             ibm-iam-service                       Running   2022-03-14T16:42:40Z
cp4waiops             operandrequest-kafkauser-iaf-system   Running   2022-03-14T17:45:48Z
ibm-common-services   ibm-commonui-request                  Running   2022-03-14T16:21:14Z
ibm-common-services   ibm-iam-request                       Running   2022-03-14T16:21:19Z
ibm-common-services   ibm-mongodb-request                   Running   2022-03-14T16:22:30Z
ibm-common-services   management-ingress                    Running   2022-03-14T16:22:30Z
ibm-common-services   platform-api-request                  Running   2022-03-14T16:22:30Z
______________________________________________________________
ODLM pod current status:

operand-deployment-lifecycle-manager-86599c9b7f-jx9h7            1/1     Running     0          7d7h
______________________________________________________________
Orchestrator pod current status:

ibm-aiops-orchestrator-controller-manager-768877589d-r7kmb        1/1     Running                 0          8d
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
```

Once you have done the above, make sure that your installation namespace is defined in the script.
By default in the script, `PROJECT_NAMESPACE` is set to `cp4waiops`. If you have a different
installation namespace name, please define the below variable with your namespace before proceeding:

```
export PROJECT_NAMESPACE="<your installation namespace>"
```

Once you have done the above, you can run the following command to use the status checker tool: 
```
oc waiops status
```
