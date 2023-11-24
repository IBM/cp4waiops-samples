#!/usr/bin/env bash

source ./00-config.sh

source ./01-create-namespace-secret-catalog-source.sh
source ./02-subscribe-ai-manager-operator.sh
source ./03-verify-ai-manager-operator.sh
source ./04-create-crd-installation.sh
source ./05-patch-aiops-analytics-orchestrators.sh
source ./06-verify-ai-manager-pods.sh
source ./07-create-secret-and-restart-nginx-pods.sh
source ./08-print-aiops-console-url-pwd.sh

install_main() {

  date1=$(date '+%Y-%m-%d %H:%M:%S')
  echo "******************************************************************************************"
  echo " IBM Cloud Pak for Watson AIOps AI-Manager started ....$date1"
  echo "******************************************************************************************"
  
  create_namespace_secret_catalog_source
  subscribe_ai_manager_operator
  verify_ai_manager_operator
  if [[ $GLOBAL_POD_VERIFY_STATUS == "true" ]]; then 
    create_crd_installation
    patch_aiops_analytics_orchestrators
    verify_ai_manager_pods
    if [[ $GLOBAL_POD_VERIFY_STATUS == "true" ]]; then 
      create_secret_and_restart_nginx_pods
    fi
    print_aiops_console_url_pwd
  fi

  date1=$(date '+%Y-%m-%d %H:%M:%S')
  echo "******************************************************************************************"
  echo " IBM Cloud Pak for Watson AIOps AI-Manager completed ....$date1"
  echo "******************************************************************************************"

}

install_main