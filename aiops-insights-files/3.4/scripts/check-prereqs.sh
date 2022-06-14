#!/bin/bash

ERROR_COUNT=0

function msg() {
    printf '%b\n' "$1"
}

function title() {
  msg "\n\33[34m# ${1}\33[0m"
}

function info() {
    msg "[INFO ] ${1}"
}

function success() {
  msg "\33[32m[INFO ] ${1}\33[0m"
}

function error() {
  msg "\33[31m[ERROR] ${1}\33[0m"
  ERROR_COUNT=$((ERROR_COUNT+1))
}

function linebreak() {
  msg ""
}

function check-command() {
    local command=$1

    if [[ -z "$(command -v ${command} 2> /dev/null)" ]]; then
      error "${command} command not available"
      exit 1
    else
      success "${command} command available"
    fi
}

function get-csv-phase {
  local CSV_NAME=$1
  local CSV_NAMESPACE=$2

  oc get $(oc get -n ${CSV_NAMESPACE} csv -o name | grep ${CSV_NAME}) --ignore-not-found -o jsonpath={.status.phase} 2> /dev/null
}

function check-operator-instance {
  local NS=$1
  local KIND=$2
  local NAME=$(oc get -n ${NS} ${KIND} -o jsonpath={.items[0].metadata.name})

  if [ -z "$(oc get ${KIND} ${NAME} -o jsonpath={.status.conditions[*].status} | grep False)" ]; then
    success "${NAME} instance is ready!"
  else
    error "${NAME} instance is not ready!"
  fi
}

title "Checking prerequisites"
info "Checking for required commands"
check-command oc

CURRENT_USER=$(oc whoami)
if [ -z "${CURRENT_USER}" ]; then
  error "oc cli is not logged in"
  exit 1
else
  success "logged in as ${CURRENT_USER}"
fi

CLUSTER_NAME=$(oc cluster-info 2> /dev/null | grep running | awk '{print $NF}' | awk -F'.' '{print $2}')
title "Cluster $CLUSTER_NAME"

NS=$(oc get subscriptions.operators.coreos.com -A | grep aimanager-operator | awk '{print $1}')
success "AIOps operator found!"

title "Checking AIOps installation status"
INSTALL_INSTANCE=$(oc get installation 2> /dev/null | grep Running | awk '{print $1}')

if [ -z "${INSTALL_INSTANCE}" ]; then
  error "AIOps installation not found!"
fi
success "AIOps installation found!"


IR_CORE_CSV_STATUS=$(get-csv-phase ibm-aiops-ir-core ${NS} 2> /dev/null)

if [ "${IR_CORE_CSV_STATUS}" == "Succeeded" ];then
  success "Issue resolution core operator is ready!"
else
  error "Issue resolution core operator is not ready!"
fi

AIOPS_UI_CSV_STATUS=$(get-csv-phase ibm-watson-aiops-ui-operator ${NS} 2> /dev/null)

if [ "${AIOPS_UI_CSV_STATUS}" == "Succeeded" ];then
  success "UI operator is ready!"
else
  error "UI operator is not ready!"
fi

check-operator-instance ${NS} IssueResolutionCore
check-operator-instance ${NS} baseui

# TODO check deployment

linebreak

info "Exiting with ${ERROR_COUNT} error(s)"
exit 0
