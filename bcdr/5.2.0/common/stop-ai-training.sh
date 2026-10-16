#!/bin/bash
#
# © Copyright IBM Corp. 2021, 2023
# 
# 
#

# Suspending the running AI training definition names where runtimeName is LUIGI before taking the backup
stopAiTraining() {
    
    namespace=$1

    echo "[INFO] $(date) Getting JWT token for sending connections API request"
    cpd_service=$(kubectl get svc -n $namespace |grep -i ibm-nginx-svc | cut -d " " -f 1)
    CPD_ROUTE="$cpd_service.$namespace.svc.cluster.local"
    #CPD_ROUTE=$(kubectl get route cpd -n $namespace --no-headers=true | awk '{print $2}')
    ZEN_BROKER_SECRET=$(kubectl get secret $(kubectl get secrets -n $namespace| grep zen-service-broker-secret | awk '{print $1;}') -n $namespace -o jsonpath="{.data.token}" | base64 -d)
    resp=$(curl -k -H "secret: $ZEN_BROKER_SECRET" https://${CPD_ROUTE}/zen-data/internal/v1/service_token?uid=1000330999&expiration_time=30)
    if [ $? -ne 0 ] || [ "$resp" == "" ]; then
        echo "Failed to get JWT token"
        exit 1
    fi
        JWT_TOKEN=$(echo $resp | awk -F'\"' '{print $4}')
    
    echo "[INFO] $(date) Getting the ElasticSearch username, password and URL"
    es_cred_secret_prefix=$(kubectl get installations.orchestrator.aiops.ibm.com -n $namespace --no-headers |  cut -d " " -f 1)
    #es_cred_secret=$es_cred_secret_prefix-elastic-secret
    es_cred_secret="aiops-opensearch-admin-creds"
    echo -e "[INFO] $(date) Reading Elastic Search secret: $es_cred_secret"
    encoded_password=$(kubectl get secret $es_cred_secret -o json -n $namespace | jq -r '.data.elastic')
    echo -e "\n"
    #echo -e "encoded username: $encoded_username"
    username="elastic"
    password=$(echo $encoded_password | base64 -d)
    #es_service=$(kubectl get service -n $namespace | grep -i elasticsearch-srv  | cut -d " " -f 1)
    #es_url="$es_service.$namespace.svc.cluster.local"
    es_url="aiops-opensearch.$namespace.svc.cluster.local:9200"
    #es_url=$(kubectl get route iaf-system-es -n $namespace -o json | jq -r '.spec.host')

    echo "[INFO] $(date) Getting the AI training definition name where runtimeName is LUIGI"
    definitionnames=$(curl -k -u "$username:$password"  -X GET  https://$es_url/trainingdefinition/_search?pretty |jq -r ".hits.hits[] | select(.. | .runtimeName? == \"LUIGI\")._source.definitionName")
    echo "Defintion names are $definitionnames"
    
    if [[ -z "$definitionnames" ]]; then
        echo "[INFO] $(date) No running AI training definition name found!"
        return 1
    fi

    echo "[INFO] $(date) Getting the URL for API Server Graphql"
    AI_PLATFORM_API_SERVER_SERVICE=$(kubectl get svc -n $namespace|grep platform-api-server|cut -d " " -f 1)
    AIMANAGER_AIO_AI_PLATFORM_API_SERVER_SERVICE_PORT=$(kubectl get svc -n $namespace $AI_PLATFORM_API_SERVER_SERVICE -o=jsonpath='{.spec.ports[0].port}')
    export API_SERVER_GRAPHQL="https://$AI_PLATFORM_API_SERVER_SERVICE.$namespace.svc:$AIMANAGER_AIO_AI_PLATFORM_API_SERVER_SERVICE_PORT/graphql/"
    echo $API_SERVER_GRAPHQL
    
    apiserver_pod=$(kubectl get pods -n $namespace  --field-selector=status.phase=Running --no-headers=true --output=custom-columns=NAME:.metadata.name | grep platform-api-server)
    #kubectl exec  $apiserver_pod  -- bash -c "cat /etc/ssl/certs/aiops-cert.pem" > tls.cert

    echo "[INFO] $(date) Suspending the running AI training definition names where runtimeName is LUIGI"
    for def in ${definitionnames}; do
        echo "Stopping the training definition name $def...."
        kubectl exec -n $namespace $apiserver_pod -- curl -H "content-type: application/json" -H "Authorization: Bearer ${JWT_TOKEN}" --request POST $API_SERVER_GRAPHQL -k -d "{\"query\":\"mutation {stopTrainingRun(definitionName:\\\"$def\\\") {status}}\"}"
    done
    
}
