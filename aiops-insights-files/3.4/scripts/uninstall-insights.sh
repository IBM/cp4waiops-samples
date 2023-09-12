#!/bin/bash
#
# © Copyright IBM Corp. 2022, 2023
# 
# 
#

NS=$(oc get subscriptions.operators.coreos.com -A | grep aimanager-operator | awk '{print $1}')
CR_INSTANCE_NAME="insightsui-instance"

oc delete -n ${NS} insightsui ${CR_INSTANCE_NAME}