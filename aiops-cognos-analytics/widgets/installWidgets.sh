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
# -- This script will install AIOps custom widgets into Cognos.
# 
# -- Before running this script, perform the following:
# --   Have your Cognos server URL and API key available
# 
# --   Usage: installWidgets.sh -u cognos_url [-k cognos_api_key] [-e]
# --------------------------------------------------------------------------------
args=$*
url=
apiKey=
sessionKey=
zipFile=
cpdRoute=
aiopsNamespace=
authHeader=

function usage() {
  echo "Usage: $0 -u cognos_url [-k cognos_api_key] [-e]" 1>&2
  echo
  exit 1
}

function prereqCheck() {
  vars=$(getopt u:k:e $args)  
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
    -e)
      embedded=true
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

  if [[ ! -z $embedded ]]; then
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

    cpdRoute="https://$(kubectl get route cpd -n ${aiopsNamespace} -o jsonpath={.spec.host} 2>/dev/null)"
    if [ -z $cpdRoute ]; then
      echo "Cloud Pak for AIOps route not found. Make sure you're logged into the right cluster and have access to the AIOps namespace."
      echo
      exit 1
    fi

    adminUser=$(kubectl -n ${aiopsNamespace} get secret platform-auth-idp-credentials -o jsonpath={.data.admin_username} | base64 -d)
    adminPass=$(kubectl -n ${aiopsNamespace} get secret platform-auth-idp-credentials -o jsonpath={.data.admin_password} | base64 -d)
    accessToken=$(curl -k -H "username: ${adminUser}" -H "password: ${adminPass}" ${cpdRoute}/v1/preauth/validateAuth 2> /dev/null | jq -r '.accessToken')
    authHeader="Authorization: Bearer ${accessToken}"
    url=$url/cognosanalytics/${aiopsNamespace}
  fi

  nodeVer=$(node -v | grep "^v18" 2>&1)
  if [ -z $nodeVer ]; then
    echo "Node.js v18+ is required."
    echo
    exit 1
  fi
  echo
}

function loginCognos() {
  echo "Logging into Cognos server $url ..."
  if [ -z $apiKey ]; then
    echo "Without an API key, anonymous Cognos login will be used."
    sessionKey=$(curl -k $url/api/v1/session -H "$authHeader" 2>/dev/null | jq -r ".session_key" 2>/dev/null)
  else
    sessionKey=$(curl -k -X PUT $url/api/v1/session -d "{\"parameters\":[{\"name\":\"CAMAPILoginKey\",\"value\":\"$apiKey\"}]}" -H "Content-Type: application/json" -H "$authHeader" 2>/dev/null | jq -r ".session_key" 2>/dev/null)
  fi
  if [[ $sessionKey = "null" ]] || [[ -z $sessionKey ]]; then
    echo
    if [ -z $apiKey ]; then
      echo "Error logging into Cognos server $url. Check the URL, and ensure anonymous access is enabled. If Cognos is embedded within AIOps, use the -e option."
    else
      echo "Error logging into Cognos server $url. Check the URL and API key, and ensure the server is running. If Cognos is embedded within AIOps, use the -e option."
    fi
    exit 1
  fi
  echo
}

function buildWidgets() {
  echo "Building AIOps widgets ..."
  npm run build
  if [ $? -gt 0 ]; then
    exit 1
  fi
  zipFile=$(ls -t ../dist/*.zip | tail -1)
  if [ -z $zipFile ]; then
    echo "Widget package not found."
    echo
    exit 1
  fi
  echo
}

function installWidgets() {
  echo "Installing AIOps widgets ..."
  message=$(curl -k -X POST $url/api/v1/extensions -H "Content-Type: application/zip" -H "IBM-BA-Authorization: $sessionKey" -H "$authHeader" --data-binary @$zipFile 2>/dev/null | jq -r ".message")
  ret=$?
  if [[ ! -z $message ]] && [[ $message != "null" ]]; then
    echo $message
  fi
  echo
}

function main() {
  prereqCheck
  loginCognos
  buildWidgets
  installWidgets
  echo "Done"
}

main
