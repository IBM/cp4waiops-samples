#!/bin/bash
#
# -------------------------------------------------------------------------------
# --
# -- © Copyright IBM Corp. 2024
# 
# -- This source code is licensed under the Apache-2.0 license found in the
# -- LICENSE file in the root directory of this source tree.
# --
# -------------------------------------------------------------------------------
# -- This script will configure single-signon so between Cloud Pak for AIOps
# -- and an existing Cognos.
# 
# -- Before running this script, perform the following:
# --   (1) Authenticate with the Cloud Pak for AIOps cluster using kubectl as an admin user.
# --   (2) Have your Cognos server URL and API key available
# 
# --   Usage: setupCognos.sh -u cognos_url [-k cognos_api_key] [-n cognos_namespace] [-g cognos_gateway] [-c aiops_client] [-r]
# --------------------------------------------------------------------------------
args=$*
url=
apiKey=
remove=
client=
cognosNamespace=
gateway=/bi
cpRoute=
aiopsNamespace=
sessionKey=


# use cluster name as default for both cognos ns and oidc client
function setDefaults() {
  current_context=$(kubectl config view -n ${aiopsNamespace} -o jsonpath={.current-context} | awk -F/ '{ print $2 }')
  default=${current_context#api-}
  default=${default%%-*}
  default=${default:-aiops-2-cognos}
  if [ -z $client ]; then
    client=$default
  fi
  if [ -z $cognosNamespace ]; then
    cognosNamespace=$default
  fi
}

function usage() {
  echo "Usage: $0 -u cognos_url [-k cognos_api_key] [-n cognos_namespace] [-g cognos_gateway] [-c aiops_client] [-r]" 1>&2
  echo
  exit 1
}

function prereqCheck() {
  vars=$(getopt u:k:c:n:r $args)  
  set -- $vars
  while :; do
    case "$1" in
    -u)
      url=$2
      shift; shift
      ;;
    -k)
      apiKey=$2
      shift; shift
      ;;
    -c)
      client=$2
      shift; shift
      ;;
    -n)
      cognosNamespace=$2
      shift; shift
      ;;
    -g)
      gateway=$2
      shift; shift
      ;;
    -r)
      remove=true
      shift
      ;;
    --) shift; 
      break 
      ;;
    esac
  done

  if [ -z $url ]; then
    usage
  else
    curl -ks $url >/dev/null 2>&1
    if [ $? -gt 0 ]; then
      echo "URL $url is not valid."
      echo
      exit 1
    fi
  fi

  echo "Checking prereqs ..."
  echo

  type kubectl > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo "kubectl command not found. Make sure this is in your PATH."
    echo
    exit 1
  fi

  kubectl auth can-i "*" "*" <<< test > /dev/null 2>&1
  if [ $? -gt 0 ]; then
    echo "Authenticate with the Cloud Pak for AIOps cluster using kubectl or oc as an admin user."
    echo
    exit 1
  fi

  aiopsNamespace=$(kubectl get subscriptions.operators.coreos.com -A 2>/dev/null | grep ibm-aiops-orchestrator | awk '{print $1}')
  if [ -z $aiopsNamespace ]; then
    echo "Cloud Pak for AIOps namespace not found. Make sure you're logged into the right cluster and have access to this namespace"
    echo
    exit 1
  fi

  cpRoute=$(kubectl get cm management-ingress-ibmcloud-cluster-info -n ${aiopsNamespace} -o jsonpath={.data.cluster_endpoint})
  if [ -z $cpRoute ]; then
    echo "Cloud Pak for AIOps cluster endpoint not found. Make sure you're logged into the right cluster and have access to the AIOps namespace."
    echo
    exit 1
  fi

  cpdRoute="https://$(kubectl get route cpd -n ${aiopsNamespace} -o jsonpath={.spec.host} 2>/dev/null)"
  if [ -z $cpdRoute ]; then
    echo "Cloud Pak for AIOps route not found. Make sure you're logged into the right cluster and have access to the AIOps namespace."
    echo
    exit 1
  fi

  setDefaults
}

function loginCognos() {
  echo "Logging into Cognos server $url ..."
  if [ -z $apiKey ]; then
    echo "Without an API key, anonymous Cognos login will be used."
    sessionKey=$(curl -k $url/api/v1/session 2>/dev/null | jq -r ".session_key" 2>/dev/null)
  else
    sessionKey=$(curl -k -X PUT $url/api/v1/session -d "{\"parameters\":[{\"name\":\"CAMAPILoginKey\",\"value\":\"$apiKey\"}]}" -H "Content-Type: application/json" 2>/dev/null | jq -r ".session_key" 2>/dev/null)
  fi
  if [[ $sessionKey = "null" ]] || [[ -z $sessionKey ]]; then
    echo
    if [ -z $apiKey ]; then
      echo "Error logging into Cognos server $url. Check the URL, and ensure anonymous access is enabled."
    else
      echo "Error logging into Cognos server $url. Check the URL and API key, and ensure the server is running."
    fi
    exit 1
  fi
  echo
}

function createClient() {
  existing=($(kubectl get client --no-headers | awk '{print $1}'))
  rename=$client
  while [[ ${existing[@]} =~ (^| )$rename($| ) ]]; do
    read -p "OIDC client $rename already exists - Provide a new name or use existing [$client]: " rename
    if [[ -z $rename ]]; then
      rename=$client
    fi
    if [[ $client = $rename ]] || [[ ! ${existing[@]} =~ (^| )$rename($| ) ]]; then
      client=$rename
      echo
      break
    fi
  done

  if [[ ${existing[@]} =~ (^| )$client($| ) ]]; then
    read -n 1 -p "Do you want to update OIDC client $client? [yN] " continue
    echo
    case $continue in
    [yY])
      echo
      echo "Updating ..."
      ;;
    *)
      echo "Skipping"
      echo
      return
      ;;
    esac
    kubectl patch client $client --type merge -p "{\"spec\":{\"oidcLibertyClient\":{\"post_logout_redirect_uris\":[\"$url$gateway\"],\"redirect_uris\":[\"$url$gateway/completeAuth.jsp\"],\"trusted_uri_prefixes\":[\"$url$gateway\"]}}}" -n $aiopsNamespace
  else
    echo "Creating OIDC client $client ..."
    kubectl create -f - << EOF
      apiVersion: oidc.security.ibm.com/v1
      kind: Client
      metadata:
        name: $client
        namespace: $aiopsNamespace
      spec:
        secret: $client-oidcclient-secret
        oidcLibertyClient:
          post_logout_redirect_uris:
          - $url$gateway
          redirect_uris:
          - $url$gateway/completeAuth.jsp
          trusted_uri_prefixes:
          - $url$gateway
EOF
  fi

  if [ $? -gt 0 ]; then
    echo
    exit 1
  fi
  echo
}

function removeClient() {
  echo "Removing OIDC client $client ..."
  kubectl delete client $client -n $aiopsNamespace
  echo
}

function addToAllowList() {
  echo "Adding $url to allow-list ..."
  ancestors=$(kubectl get aiopsui aiopsui-instance -o "jsonpath={.spec.container.uiServer.container.env[?(@.name==\"SECURITY__FRAMEANCESTORS\")].value}" -n $aiopsNamespace 2>/dev/null)
  if [[ ! $ancestors =~ (^| )$url($| ) ]]; then
    ancestors=($url $ancestors)
  fi
  cors=$(kubectl get aiopsui aiopsui-instance -o "jsonpath={.spec.container.uiServer.container.env[?(@.name==\"SECURITY__CORSWHITELIST\")].value}" -n $aiopsNamespace 2>/dev/null)
  if [[ ! $cors =~ (^| )$url($| ) ]]; then
    cors=($url $cors)
  fi
  kubectl patch aiopsui aiopsui-instance --type merge -p "{\"spec\":{\"container\":{\"uiServer\":{\"container\":{\"env\":[{\"name\":\"SECURITY__FRAMEANCESTORS\",\"value\":\"$ancestors\"},{\"name\":\"SECURITY__CORSWHITELIST\",\"value\":\"$cors\"}]}}}}}" -n $aiopsNamespace
  echo
}

function removeFromAllowList() {
  inUse=$(kubectl get client -o custom-columns=URLS:.spec.oidcLibertyClient.trusted_uri_prefixes --no-headers)
  if [[ ! $inUse =~ $url ]]; then
    echo "Removing $url from allow-list ..."
    ancestors=$(kubectl get aiopsui aiopsui-instance -o "jsonpath={.spec.container.uiServer.container.env[?(@.name==\"SECURITY__FRAMEANCESTORS\")].value}" -n $aiopsNamespace 2>/dev/null)
    if [[ $ancestors =~ (^| )$url($| ) ]]; then
      array=($ancestors)
      ancestors=$(echo ${array[@]/$url})
    fi
    cors=$(kubectl get aiopsui aiopsui-instance -o "jsonpath={.spec.container.uiServer.container.env[?(@.name==\"SECURITY__CORSWHITELIST\")].value}" -n $aiopsNamespace 2>/dev/null)
    if [[ $cors =~ (^| )$url($| ) ]]; then
      array=($cors)
      cors=$(echo ${array[@]/$url})
    fi
    kubectl patch aiopsui aiopsui-instance --type merge -p "{\"spec\":{\"container\":{\"uiServer\":{\"container\":{\"env\":[{\"name\":\"SECURITY__FRAMEANCESTORS\",\"value\":\"$ancestors\"},{\"name\":\"SECURITY__CORSWHITELIST\",\"value\":\"$cors\"}]}}}}}" -n $aiopsNamespace
  else
    echo "$url still in use by other OIDC clients, not removing from allow-list"
  fi
  echo
}

function testNamespace() {
  echo "Testing Cognos namespace $cognosNamespace ..."
  echo
  message=$(curl -k $url/api/v1/configuration/namespaces/test/$cognosNamespace -H "IBM-BA-Authorization: $sessionKey" 2>/dev/null | jq -r ".message")

  if [[ $message != *"success"* ]]; then
    echo "Test failed - $message"
    echo
  fi
}

function createNamespace() {
  # fetch client creds
  sleep 2
  secret=$(kubectl get secret $client-oidcclient-secret -n $aiopsNamespace -o "jsonpath={.data}")
  clientId=$(echo $secret | jq -r ".CLIENT_ID" | base64 -d)
  clientSecret=$(echo $secret | jq -r ".CLIENT_SECRET" | base64 -d)

  existing=($(curl -k $url/api/v1/configuration/namespaces -H "IBM-BA-Authorization: $sessionKey" 2>/dev/null | jq -r ".items[].id"))
  rename=$cognosNamespace
  while [[ ${existing[@]} =~ (^| )$rename($| ) ]]; do
    read -p "Cognos namespace $rename already exists - Provide a new name or use existing [$cognosNamespace]: " rename
    if [[ -z $rename ]]; then
      rename=$cognosNamespace
    fi
    if [[ $cognosNamespace = $rename ]] || [[ ! ${existing[@]} =~ (^| )$rename($| ) ]]; then
      cognosNamespace=$rename
      echo
      break
    fi
  done

  if [[ ${existing[@]} =~ (^| )$cognosNamespace($| ) ]]; then
    read -n 1 -p "Do you want to update Cognos namespace $cognosNamespace? [yN] " continue
    echo
    case $continue in
    [yY])
      echo
      echo "Updating ..."
      ;;
    *)
      echo "Skipping"
      echo
      testNamespace
      return
      ;;
    esac

    result=$(curl -k -X PUT $url/api/v1/configuration/namespaces/$cognosNamespace \
      -H "IBM-BA-Authorization: $sessionKey" \
      -H "Content-Type: application/json" \
      -d @- << EOF 2>/dev/null
      {
        "oidcDiscEndpoint": "$cpRoute/idprovider/v1/auth/.well-known/openid-configuration",
        "clientId": "$clientId",
        "returnUrl": "$url$gateway/completeAuth.jsp",
        "clientSecret": "$clientSecret",
        "customProperties": {
          "preferred_username": "preferred_username",
          "uniqueSecurityName": "uniqueSecurityName",
          "aiops_proxy": "$cpdRoute"
        }
      }
EOF
)
  else
    echo "Creating Cognos namespace $cognosNamespace ..."

    result=$(curl -k -X POST $url/api/v1/configuration/namespaces \
      -H "IBM-BA-Authorization: $sessionKey" \
      -H "Content-Type: application/json" \
      -d @- << EOF 2>/dev/null
      {
        "name": "$cognosNamespace",
        "class": "OIDC_Generic",
        "identityProviderType": "Generic",
        "id": "$cognosNamespace",
        "selectableForAuth": true,
        "useDiscoveryEndpoint": true,
        "oidcDiscEndpoint": "$cpRoute/idprovider/v1/auth/.well-known/openid-configuration",
        "clientId": "$clientId",
        "returnUrl": "$url$gateway/completeAuth.jsp",
        "authScope": "openid",
        "accountClaims": "token",
        "tokenEndpointAuth": "client_secret_post",
        "clientSecret": "$clientSecret",
        "keyLocation": "jwks_uri",
        "pgStrategy": "idToken",
        "pgInclScope": true,
        "tcStrategy": "token",
        "tcAccountClaims": "id_token",
        "accountCamidProperty": "uniqueSecurityName",
        "acEmail": "email",
        "acUsername": "preferred_username",
        "customProperties": {
          "preferred_username": "preferred_username",
          "uniqueSecurityName": "uniqueSecurityName",
          "aiops_proxy": "$cpdRoute"
        }
      }
EOF
)
  fi

  message=$(echo ${result} | jq -r '.message')
  if [[ $message != "null" ]] && [[ ! -z $message ]]; then
    echo $message
  else
    echo
    testNamespace
  fi
  echo
}

function removeNamespace() {
  echo "Removing Cognos namespace $cognosNamespace ..."
  message=$(curl -k -X DELETE $url/api/v1/configuration/namespaces/$cognosNamespace -H "IBM-BA-Authorization: $sessionKey" 2>/dev/null | jq -r ".message")
  if [[ $message != "null" ]] && [[ ! -z $message ]]; then
    echo $message
  fi
  echo
}

function main() {
  prereqCheck
  loginCognos
  if [ -z $remove ]; then
    createClient
    addToAllowList
    createNamespace
  else
    removeClient
    removeFromAllowList
    removeNamespace
  fi
  echo "Done"
}

main
