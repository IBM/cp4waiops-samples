#!/usr/bin/env bash

function print_aiops_console_url_pwd () {

echo "-----------------------------------"
echo "8.Printing AI Manager console access details..."
echo "-----------------------------------"

MY_URL=$(oc get route -n $NAMESPACE cpd -o jsonpath={.spec.host})
MY_PASSWORD=$(oc -n ibm-common-services get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 -d)

echo "===================================================================================="
echo "URL : https://$MY_URL"
echo "USER: admin"
echo "PASSWORD: $MY_PASSWORD"
echo "===================================================================================="

}