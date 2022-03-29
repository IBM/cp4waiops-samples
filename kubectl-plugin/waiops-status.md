# kubectl-waiops

A kubectl plugin for CP4WAIOps

https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/

## Highlights

### Main status checker
```
$ oc waiops status

______________________________________________________________
Installation instances:

NAMESPACE   NAME                 PHASE     LICENSE    STORAGECLASS   STORAGECLASSLARGEBLOCK   AGE
katamari    aiops-installation   Running   Accepted   rook-cephfs    rook-cephfs              14h
______________________________________________________________
IRCore and AIOpsAnalyticsOrchestrator instances:

KIND                         NAMESPACE   NAME    VERSION   STATUS
IssueResolutionCore          katamari    aiops   3.3.0     Ready
AIOpsAnalyticsOrchestrator   katamari    aiops   3.2.0     Ready
______________________________________________________________
LifecycleService instances:

KIND               NAMESPACE   NAME    VERSION   STATUS
LifecycleService   katamari    aiops   3.3.0     Ready
______________________________________________________________
BaseUI instances:

KIND     NAMESPACE   NAME              VERSION   STATUS
BaseUI   katamari    baseui-instance   3.3.1     Ready
______________________________________________________________
AIManager, ASM, AIOpsEdge, and AIOpsUI instances:

KIND        NAMESPACE   NAME             VERSION   STATUS
AIManager   katamari    aimanager        2.4.0     Completed
ASM         katamari    aiops-topology   2.5.0     OK

KIND        NAMESPACE   NAME        STATUS
AIOpsEdge   katamari    aiopsedge   Configured

KIND      NAMESPACE   NAME               VERSION
AIOpsUI   katamari    aiopsui-instance   3.3.1
______________________________________________________________
AutomationUIConfig, AutomationBase, Cartridge, and CartridgeRequirements instances:

KIND                    NAMESPACE   NAME                    VERSION   STATUS
AutomationUIConfig      katamari    iaf-system              1.3.3     True
AutomationBase          katamari    automationbase-sample   2.0.3     True
Cartridge               katamari    cp4waiops-cartridge     1.3.3     True
CartridgeRequirements   katamari    cp4waiops-cartridge     1.3.3     True
______________________________________________________________
Kong instances:

KIND   NAMESPACE   NAME
Kong   katamari    gateway
______________________________________________________________
ZenService instances:

KIND         NAME                 NAMESPACE   VERSION   STATUS
ZenService   iaf-zen-cpdservice   katamari    4.4.3     Completed
______________________________________________________________
CSVs from katamari namespace:

NAME                                               DISPLAY                                            VERSION              REPLACES                                PHASE
aimanager-operator.v3.3.1-202203282001             IBM Watson AIOps AI Manager                        3.3.1-202203282001                                           Succeeded
aiopsedge-operator.v3.3.1-202203282001             IBM Watson AIOps Edge                              3.3.1-202203282001                                           Succeeded
asm-operator.v3.3.1-202203282001                   IBM Netcool Agile Service Manager                  3.3.1-202203282001                                           Succeeded
couchdb-operator.v2.2.1                            Operator for Apache CouchDB                        2.2.1                couchdb-operator.v2.2.0                 Succeeded
elasticsearch-operator.5.3.5-20                    OpenShift Elasticsearch Operator                   5.3.5-20                                                     Succeeded
ibm-aiops-ir-ai.v3.3.1-202203282001                IBM Watson AIOps Issue Resolution AI & Analytics   3.3.1-202203282001                                           Succeeded
ibm-aiops-ir-core.v3.3.1-202203282001              IBM Watson AIOps Issue Resolution Core             3.3.1-202203282001                                           Succeeded
ibm-aiops-ir-lifecycle.v3.3.1-202203282001         IBM Cloud Pak for Watson AIOps Lifecycle           3.3.1-202203282001                                           Succeeded
ibm-aiops-orchestrator.v3.3.1-202203282001         IBM Cloud Pak for Watson AIOps AI Manager          3.3.1-202203282001                                           Succeeded
ibm-automation-core.v1.3.5                         IBM Automation Foundation Core                     1.3.5                ibm-automation-core.v1.3.4              Succeeded
ibm-automation-elastic.v1.3.4                      IBM Elastic                                        1.3.4                ibm-automation-elastic.v1.3.3           Succeeded
ibm-automation-eventprocessing.v1.3.5              IBM Automation Foundation Event Processing         1.3.5                ibm-automation-eventprocessing.v1.3.4   Succeeded
ibm-automation-flink.v1.3.4                        IBM Automation Foundation Flink                    1.3.4                ibm-automation-flink.v1.3.3             Succeeded
ibm-automation.v1.3.5                              IBM Automation Foundation                          1.3.5                ibm-automation.v1.3.4                   Succeeded
ibm-cloud-databases-redis.v1.4.3                   IBM Operator for Redis                             1.4.3                ibm-cloud-databases-redis.v1.4.2        Succeeded
ibm-common-service-operator.v3.17.0                IBM Cloud Pak foundational services                3.17.0               ibm-common-service-operator.v3.16.3     Succeeded
ibm-management-kong.v3.3.1-202203282001            IBM Internal - IBM Watson AIOps Kong               3.3.1-202203282001                                           Succeeded
ibm-postgreservice-operator.v3.3.1-202203282001    IBM Postgreservice                                 3.3.1-202203282001                                           Succeeded
ibm-secure-tunnel-operator.v3.3.1-202203282001     IBM Secure Tunnel                                  3.3.1-202203282001                                           Succeeded
ibm-vault-operator.v3.3.1-202203282001             IBM Vault Operator                                 3.3.1-202203282001                                           Succeeded
ibm-watson-aiops-ui-operator.v3.3.1-202203282001   IBM Watson AIOps UI                                3.3.1-202203282001                                           Succeeded
______________________________________________________________
CSVs from ibm-common-services namespace:

NAME                                                 DISPLAY                                VERSION    REPLACES                                       PHASE
elasticsearch-operator.5.3.5-20                      OpenShift Elasticsearch Operator       5.3.5-20                                                  Succeeded
ibm-cert-manager-operator.v3.19.0                    IBM Cert Manager                       3.19.0     ibm-cert-manager-operator.v3.18.1              Succeeded
ibm-common-service-operator.v3.17.0                  IBM Cloud Pak foundational services    3.17.0     ibm-common-service-operator.v3.16.1            Succeeded
ibm-commonui-operator.v1.15.0                        Ibm Common UI                          1.15.0     ibm-commonui-operator.v1.14.0                  Succeeded
ibm-crossplane-operator.v1.6.0                       IBM Crossplane                         1.6.0      ibm-crossplane-operator.v1.5.0                 Succeeded
ibm-crossplane-provider-kubernetes-operator.v1.6.0   IBM Crossplane Provider Kubernetes     1.6.0                                                     Succeeded
ibm-events-operator.v3.15.0                          IBM Events Operator                    3.15.0     ibm-events-operator.v3.14.2                    Succeeded
ibm-iam-operator.v3.17.0                             IBM IAM Operator                       3.17.0     ibm-iam-operator.v3.16.0                       Succeeded
ibm-ingress-nginx-operator.v1.14.0                   IBM Ingress Nginx Operator             1.14.0     ibm-ingress-nginx-operator.v1.13.0             Succeeded
ibm-licensing-operator.v1.14.0                       IBM Licensing Operator                 1.14.0     ibm-licensing-operator.v1.13.0                 Succeeded
ibm-management-ingress-operator.v1.14.0              Management Ingress Operator            1.14.0     ibm-management-ingress-operator.v1.12.0        Succeeded
ibm-mongodb-operator.v1.12.0                         IBM MongoDB Operator                   1.12.0     ibm-mongodb-operator.v1.11.0                   Succeeded
ibm-namespace-scope-operator.v1.11.0                 IBM NamespaceScope Operator            1.11.0     ibm-namespace-scope-operator.v1.10.0           Succeeded
ibm-platform-api-operator.v3.19.0                    IBM Platform API                       3.19.0     ibm-platform-api-operator.v3.18.0              Succeeded
ibm-zen-operator.v1.5.3                              IBM Zen Service                        1.5.3      ibm-zen-operator.v1.5.2                        Succeeded
operand-deployment-lifecycle-manager.v1.15.0         Operand Deployment Lifecycle Manager   1.15.0     operand-deployment-lifecycle-manager.v1.14.0   Succeeded
______________________________________________________________
Subscriptions from katamari namespace:

NAME                                                                         PACKAGE                              SOURCE                  CHANNEL
aimanager-operator                                                           aimanager-operator                   ibm-cp-waiops-catalog   3.3-dev
aiopsedge-operator                                                           aiopsedge-operator                   ibm-cp-waiops-catalog   3.3-dev
asm-operator                                                                 asm-operator                         ibm-cp-waiops-catalog   3.3-dev
couchdb                                                                      couchdb-operator                     ibm-cp-waiops-catalog   v2.2
ibm-aiops-orchestrator                                                       ibm-aiops-orchestrator               ibm-cp-waiops-catalog   3.3-dev
ibm-automation                                                               ibm-automation                       iaf-operators           v1.3
ibm-automation-core-v1.3-iaf-core-operators-openshift-marketplace            ibm-automation-core                  iaf-core-operators      v1.3
ibm-automation-elastic-v1.3-iaf-operators-openshift-marketplace              ibm-automation-elastic               iaf-operators           v1.3
ibm-automation-eventprocessing-v1.3-iaf-operators-openshift-marketplace      ibm-automation-eventprocessing       iaf-operators           v1.3
ibm-automation-flink-v1.3-iaf-operators-openshift-marketplace                ibm-automation-flink                 iaf-operators           v1.3
ibm-common-service-operator-v3-ibm-cp-waiops-catalog-openshift-marketplace   ibm-common-service-operator          opencloud-operators     v3
ibm-management-kong                                                          ibm-management-kong                  ibm-cp-waiops-catalog   3.3-dev
ibm-postgreservice-operator                                                  ibm-postgreservice-operator          ibm-cp-waiops-catalog   3.3-dev
ibm-secure-tunnel-operator                                                   ibm-secure-tunnel-operator           ibm-cp-waiops-catalog   3.3-dev
ibm-watson-aiops-ui-operator                                                 ibm-watson-aiops-ui-operator         ibm-cp-waiops-catalog   3.3-dev
ir-ai-operator                                                               ibm-aiops-ir-ai                      ibm-cp-waiops-catalog   3.3-dev
ir-core-operator                                                             ibm-aiops-ir-core                    ibm-cp-waiops-catalog   3.3-dev
ir-lifecycle-operator                                                        ibm-aiops-ir-lifecycle               ibm-cp-waiops-catalog   3.3-dev
redis                                                                        ibm-cloud-databases-redis-operator   ibm-cp-waiops-catalog   v1.4
vault                                                                        ibm-vault-operator                   ibm-cp-waiops-catalog   3.3-dev
______________________________________________________________
Subscriptions from ibm-common-services namespace:

NAME                                              PACKAGE                                           SOURCE                CHANNEL
ibm-cert-manager-operator                         ibm-cert-manager-operator                         opencloud-operators   v3
ibm-common-service-operator                       ibm-common-service-operator                       opencloud-operators   v3
ibm-commonui-operator                             ibm-commonui-operator-app                         opencloud-operators   v3
ibm-crossplane-operator-app                       ibm-crossplane-operator-app                       opencloud-operators   v3
ibm-crossplane-provider-kubernetes-operator-app   ibm-crossplane-provider-kubernetes-operator-app   opencloud-operators   v3
ibm-events-operator                               ibm-events-operator                               opencloud-operators   v3
ibm-iam-operator                                  ibm-iam-operator                                  opencloud-operators   v3
ibm-ingress-nginx-operator                        ibm-ingress-nginx-operator-app                    opencloud-operators   v3
ibm-licensing-operator                            ibm-licensing-operator-app                        opencloud-operators   v3
ibm-management-ingress-operator                   ibm-management-ingress-operator-app               opencloud-operators   v3
ibm-mongodb-operator                              ibm-mongodb-operator-app                          opencloud-operators   v3
ibm-namespace-scope-operator                      ibm-namespace-scope-operator                      opencloud-operators   v3
ibm-platform-api-operator                         ibm-platform-api-operator-app                     opencloud-operators   v3
ibm-zen-operator                                  ibm-zen-operator                                  opencloud-operators   v3
operand-deployment-lifecycle-manager-app          ibm-odlm                                          opencloud-operators   v3
______________________________________________________________
OperandRequest instances:

NAMESPACE             NAME                                  PHASE     CREATED AT
ibm-common-services   ibm-commonui-request                  Running   2022-03-29T05:19:25Z
ibm-common-services   ibm-iam-request                       Running   2022-03-29T05:19:25Z
ibm-common-services   ibm-mongodb-request                   Running   2022-03-29T05:20:14Z
ibm-common-services   management-ingress                    Running   2022-03-29T05:20:14Z
ibm-common-services   platform-api-request                  Running   2022-03-29T05:20:14Z
katamari              aiopsedge-base                        Running   2022-03-29T05:25:27Z
katamari              aiopsedge-cs                          Running   2022-03-29T05:25:27Z
katamari              iaf-core-operator                     Running   2022-03-29T05:16:19Z
katamari              iaf-eventprocessing-operator          Running   2022-03-29T05:16:14Z
katamari              iaf-operator                          Running   2022-03-29T05:16:10Z
katamari              iaf-system                            Running   2022-03-29T05:29:15Z
katamari              iaf-system-common-service             Running   2022-03-29T05:19:20Z
katamari              ibm-aiops-ai-manager                  Running   2022-03-29T05:18:50Z
katamari              ibm-aiops-aiops-foundation            Running   2022-03-29T05:18:50Z
katamari              ibm-aiops-application-manager         Running   2022-03-29T05:18:50Z
katamari              ibm-aiops-connection                  Running   2022-03-29T05:18:50Z
katamari              ibm-elastic-operator                  Running   2022-03-29T05:16:21Z
katamari              ibm-iam-service                       Running   2022-03-29T05:43:37Z
katamari              operandrequest-kafkauser-iaf-system   Running   2022-03-29T05:52:39Z
______________________________________________________________
ODLM pod current status:

ibm-common-services                                operand-deployment-lifecycle-manager-687db67764-zb86w               1/1     Running     0          14h
______________________________________________________________
Orchestrator pod current status:

katamari                                           ibm-aiops-orchestrator-controller-manager-797979ccf8-9nzzs          1/1     Running     0          14h
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

Once you have done the above, you can run the following commands to use the status checker tool: 
```
oc waiops status 
oc waiops upgrade-status
```
