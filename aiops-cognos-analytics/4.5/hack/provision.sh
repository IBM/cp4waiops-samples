#!/usr/bin/env bash
#
# -----------------------------------------------------------------------------
#         Licensed Materials - Property of IBM
#
#         IBM Cognos Products: ca
#
#         (C) Copyright IBM Corp. 2023
#
#         US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule
# -----------------------------------------------------------------------------
#
#

set +x

# variables used plus any defaults
externalCS=true
provision_timeout="60"
remove_running_instance=false
cd_db_host=""
cd_db_name=""
cd_db_pass=""
cd_db_port=""
cd_db_provider=""
cd_db_user=""
dbserver_id=""
dbserver_pass=""
use_ssl="false"
cert_file=""
sslCert=""
plan_size="xsmall"
oc_route=""
crypto_conformance=""
crypto_conformance_label=""
connection_name=""

function usageError() {
  local msg=$1
  echo "$1"
  echo
  usage
  exit 1
}

function checkPlanSize() {
  case "$1" in
    fixedminimum|xsmall|small|small_mincpureq|medium|large)
      echo "Using plan size: $1"
      return 0
      ;;
  esac

    echo "Plan size of $1 is invalid."
    exit 1
}

function usage {
    echo $0: usage: $0 [-h] -n namespace [-t tethered_namespace] -f file_storageclass [-b block_storageclass] [-p plan_size][-d connection_name][-C database_provider -H database_host -D database_name -U database_user -P database_password -L database_port][-X ca_username][-Y ca_password] -V addon_version [-T provision_timeout][-R][-S cert_file][-s][-i dbserver_id][-j dbserver_pass][-c crypto_conformance]
}

function help {
    usage
    echo "-h  prints help to the console"
    echo "-n  namespace Project namespace"
    echo "-t  tethered namespace (optional)"
    echo "-f  file storageclass Cluster Storage Class"
    echo "-b  block storageclass Cluster Storage Class(Optional else will default to file storage)"
    echo "-c  crypto_conformance Crypto Conformance value; FIPS_140"
    echo "-p  plan size"
    echo "-d  connection_name Database connection name"
    echo "-C  cd_db_provider  Database Provider"
    echo "-H  cd_db_host  Database Host"
    echo "-D  cd_db_name  Database Name"
    echo "-U  cd_db_user  Database User"
    echo "-P  cd_db_pass  Database Password"
    echo "-L  cd_db_port  Database Port"
    echo "-X  ca_username  CPD username"
    echo "-Y  ca_password  CPD password"
    echo "-i  dbserver_id Database Server User ID"
    echo "-j  dbserver_pass Database Server Password"
    echo "-V  addon_version Addon Version"
    echo "-T  provision_timeout Provision Timeout in minutes"
    echo "-R  Flag set to true will check for any old running instances to be purged if any"
    echo "-S  ssl_file Use ssl CS connection"
    echo "-s  Flag to use ssl CS connection"
    echo ""
    exit 0
}

while getopts ":hn:t:f:b:p:d:C:H:D:U:i:j:L:P:X:Y:V:T:RsS:c:" opt; do
     case ${opt} in
     n)
        namespace=$OPTARG
        ;;
     t)
        tethered_namespace=$OPTARG
        ;;
     f)
        file_storageclass=$OPTARG
        ;;
     b)
        block_storageclass=$OPTARG
        ;;
     c)
        crypto_conformance=$OPTARG
        if [ "$crypto_conformance" == "FIPS_140" ]; then
            crypto_conformance_label="FIPS 140-2"
        fi
        ;;
     p)
        plan_size=$OPTARG
        ;;
     d)
        connection_name=$OPTARG
        ;;
     C)
        cd_db_provider=$OPTARG
        ;;
     H)
        cd_db_host=$OPTARG
        ;;
     D)
        cd_db_name=$OPTARG
        ;;
     U)
        cd_db_user=$OPTARG
        ;;
     P)
        cd_db_pass=$OPTARG
        ;;
     L)
        cd_db_port=$OPTARG
        ;;
     X)
        ca_username=$OPTARG
        ;;
     Y)
        ca_password=$OPTARG
        ;;
     i)
        dbserver_id=$OPTARG
        ;;
     j)
        dbserver_pass=$OPTARG
        ;;
     V)
        addon_version=$OPTARG
        ;;
     T)
        provision_timeout=$OPTARG
        ;;
     R)
        remove_running_instance=true
        ;;
     S)
        use_ssl="true"
        cert_file=$OPTARG
        ;;
     s)
        use_ssl="true"
        cert_file="_"
        ;;
     h)
        help
        ;;
     \?)
        usage
        exit 0
        ;;
     esac
done

# Check for pre-requisites
echo
echo "Is oc installed?"
if ! oc version;
then
	echo "oc not installed. Please install oc."
	exit 1
fi

#Checking if jq is installed
echo "Is jq installed?"
if ! jq --version;
then
  echo "jq not installed . Please install jq"
  exit 1
fi

# Verify all required parameters
if [ -z "$namespace" ]; then
  usageError "Please provide an instance namespace."
fi
if [ -z "${tethered_namespace}" ]; then
  echo "Setting tethered namespace same as instance namespace."
  tethered_namespace=${namespace}
fi
if [ -z "$file_storageclass" ]; then
  usageError "Please provide a file storage class."
fi
if [[ -z ${block_storageclass} || ${block_storageclass} == "" ]];then
  echo "Setting block storage same as file storage class."
  block_storageclass=${file_storageclass}
fi
if [ -z "${addon_version}" ]; then
  usageError "Please provide the addon version you wish to provision."
fi
if [ -z "${connection_name}" ]; then
  if [ -z "${cd_db_provider}" ]; then
    usageError "Please provide the content database provider."
  fi
  if [ -z "${cd_db_host}" ]; then
    usageError "Please provide the content database host."
  fi
  if [ -z "${cd_db_port}" ]; then
    usageError "Please provide the content database port."
  fi
  if [ -z "${cd_db_name}" ]; then
    usageError "Please provide the content database name."
  fi
  if [ -z "${cd_db_user}" ]; then
    usageError "Please provide the content database user name."
  fi
  if [ -z "${cd_db_pass}" ]; then
    usageError "Please provide the content database user password."
  fi

  if [ "${use_ssl}" == "true" ] ; then
    echo "SSL is enabled ..."
    if [ -z "$cert_file" ]; then
        usageError "Please provide a valid certificate file."
    fi

    if [ "$cert_file" != "_" ]; then
      sslCert=$(cat "${cert_file}" | tr -s '\r\n' '\\n')
      echo "Checking for valid certificate..."
      if [[ ${sslCert} == "" || -z ${sslCert} ]] ; then
        usageError "Please provide a valid ssl certificate"
      fi
    fi
  fi
else
  cd_db_port=0
fi

checkPlanSize "$plan_size"

if [ -z ${ca_username} ] && [ -z ${ca_password} ]; then
  echo "User name / Password has not been provided, retrieving from system ..."
  cr_name=$(oc -n ${namespace} get zenservice --no-headers -o custom-columns=NAME:.metadata.name)

  if [ -z $cr_name ]; then
      echo "Unable to find ZenService CR for namespace: ${namespace}"
      exit 1
  fi
  echo "Checking ${cr_name} to see if IAM is enabled or not ..."

  isIAMEnabled=$(oc get zenservice ${cr_name} -n ${namespace} -o jsonpath={.spec.iamIntegration})
  if [[ ${isIAMEnabled} == "true" ]];then
    echo "IAM is enabled."
    ca_password=$(oc -n ${namespace} get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
    ca_username=$(oc -n ${namespace} get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)
  else
    echo "IAM is not enabled."
    ca_password=$(oc get secret admin-user-details -o jsonpath='{.data.initial_admin_password}' -n ${namespace} | base64 --decode)
    ca_username="admin"
  fi
fi

if [[ ${oc_route} == "" || -z ${oc_route} ]] ; then
  echo "Locating route ..."
  oc_route=$(oc get route -n $namespace |grep ibm-nginx-svc|awk '{print $2}')
  echo "${oc_route}"
fi

cpd_web_url="https://${oc_route}"
echo "CPD Web URL: $cpd_web_url"

function provision_data() {
  tls_enabled=false
  cat << EOF
{
  "addon_type": "cognos-analytics-app",
  "display_name": "Cognos Analytics in ${tethered_namespace}",
  "namespace": "${tethered_namespace}",
  "addon_version": "${addon_version}",
  "create_arguments": {
    "deployment_id": "",
    "parameters": {
      "global.cp4dWebUrl": "${cpd_web_url}:443/cognosanalytics/bi/v1/disp",
      "global.cp4dWebUrlBase": "${cpd_web_url}",
      "global.icp4Data": "true",
      "global.tls.enabled": "${tls_enabled}",
      "global.icp4DataVersion": "${addon_version}",
      "global.cs.databaseExternal": "true",
      "global.cs.databaseConnectionName": "${connection_name}",
      "global.cs.databaseProvider": "${cd_db_provider}",
      "global.cs.databaseHost": "${cd_db_host}",
      "global.cs.databasePort": ${cd_db_port},
      "global.cs.databaseName": "${cd_db_name}",
      "global.cs.databaseUser": "${cd_db_user}",
      "global.cs.databasePass": "${cd_db_pass}",
      "global.cs.databaseTlsEnabled": "${use_ssl}",
      "global.audit.databaseExternal": "true",
      "global.audit.databaseConnectionName": "${connection_name}",
      "global.audit.databaseProvider": "${cd_db_provider}",
      "global.audit.databaseHost": "${cd_db_host}",
      "global.audit.databasePort": ${cd_db_port},
      "global.audit.databaseName": "${cd_db_name}",
      "global.audit.databaseUser": "${cd_db_user}",
      "global.audit.databasePass": "${cd_db_pass}",
      "global.audit.databaseTlsEnabled": "${use_ssl}",
      "pvc.pvProvisioning": "NamedStorageClass",
      "pvc.storageClassName": "${file_storageclass}",
      "pvc.blockStorageClassName": "${block_storageclass}",
      "metadata.planSize": "${plan_size}",
      "metadata.storageType": "storage-class",
      "metadata.storageClass": "${file_storageclass}",
      "metadata.cryptoConformanceLabel": "${crypto_conformance_label}",
      "metadata.cryptoConformance": "${crypto_conformance}",
      "metadata.autoScaleConfig": "true"
EOF

  if [ "${use_ssl}" == "true" ];then
    cat << EOF
      ,"external_cs_ssl_cert": {
        "certificationPurpose": "EXT_CS",
        "fileData": "${sslCert}"
      }
EOF

  fi
  cat << EOF
    },
    "resources": {
      "cpu": "9",
      "gpu": "0",
      "memory": "22.59"
    },
    "description": "",
    "metaData": {
      "planSize": "${plan_size}",
      "sharedStorageType": "storage-class",
      "sharedStorageClass": "${file_storageclass}",
      "storageType": "storage-class",
      "storageClass": "${file_storageclass}",
      "contentStoreStorageLabelKey": "",
      "contentStoreStorageLabelValue": ""
    },
    "owner_username": ""
  },
  "transient_fields": {}
}
EOF
}

echo "Performing Login using ${ca_username} ..."
my_tmp_dir="$(mktemp -d)" || { echo "Failed to create temp dir"; exit 1; }
zen_cookie_file=${my_tmp_dir}/zen.cookie

loginRequestResponse=$(curl -k -X GET "${cpd_web_url}/v1/preauth/validateAuth" \
    -H "Content-Type: application/json;charset=UTF-8" \
    -H "username: ${ca_username}" \
    -H "password: ${ca_password}")
loginRequestResponseStatus=$(jq -r '._messageCode_' <<< ${loginRequestResponse})
if [[ ${loginRequestResponseStatus} != "success" ]]; then
    echo "Login Failed. Provisioning will abort"
    exit 1
fi
echo "Getting the Auth token ..."
auth_token=$(curl -k -X POST \
  "${cpd_web_url}/icp4d-api/v1/authorize" \
  -H "Content-Type: application/json;charset=UTF-8" \
  -d '{"username": "'"${ca_username}"'","password": "'"${ca_password}"'"}')
bearer_auth_token=$(jq -r '.token' <<< ${auth_token})
tokenResponseStatus=$(jq -r '.message' <<< ${auth_token})
if [[ ${tokenResponseStatus} != "Success" ]]; then
    echo "Failed to Get Token Failed. Provisioning will abort"
    exit 1
fi

if [[ ${remove_running_instance} == "true" ]]; then
  echo "Cleaning up running instances"
  echo "Checking for any running instance ..."
  get_status_response=$(curl -v -k -H "Content-Type:application/json" -H "Authorization: Bearer ${bearer_auth_token}" -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -X GET ${cpd_web_url}/zen-data/v3/service_instances?addon_type=cognos-analytics-app)
#  echo "get_status_response: ${get_status_response}"
  total_count=$(jq -r '.total_count' <<< ${get_status_response})
  echo "Number of instances: $total_count"
  echo "Fetching instance id ..."

  function instanceStatus(){
    instance_status_response=$(curl -v -k -H "Content-Type:application/json" -H "Authorization: Bearer ${bearer_auth_token}" -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -X GET ${cpd_web_url}/zen-data/v3/service_instances/${instance_id}/?include_service_status=true)
    instance_status=$(jq -r '.services_status' <<< ${instance_status_response})
    echo "Instance Status is $instance_status"
  }

  if [[ ${total_count} != 0 ]] ; then
      currInstance=0
      while [ ${currInstance} -lt ${total_count} ]; do
        instance_namespace=$(jq -r ".service_instances[${currInstance}].namespace" <<< ${get_status_response})
        if [ "${instance_namespace}" != "${tethered_namespace}"  ]; then
            ((currInstance+=1))
            echo "Remove instance skipping namespace: ${instance_namespace}"
            continue
        fi
        instance_id=$(jq -r ".service_instances[${currInstance}].id" <<< ${get_status_response})
        echo "Removing instance namespace: ${instance_namespace}"
        echo "Instance Id of the running instance of Cognos is: ${instance_id}"
        ((currInstance+=1))

        echo "Deleting running instance ..."
        curl -v -k -H "Content-Type:application/json" -H "Authorization: Bearer ${bearer_auth_token}" -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -X DELETE ${cpd_web_url}/zen-data/v3/service_instances/${instance_id}
        #Getting instance status of the deleted instance
        instanceStatus
        # Waiting for the instance to be deleted before provisioning
        cnt=0
        while [[ ${instance_status} == "RUNNING" || ${instance_status} == "DELETING" || ${instance_status} == "PENDING" ]]
        do
          let cnt+=1
          if [[ ${cnt} -lt 20 ]]; then
            if [[ ${instance_status} != null ]] ; then
              echo -n "."
              instanceStatus
              sleep 60
            else
              echo "Instance Deleted Successfully."
              break
            fi
          else
            echo "Instance failed to be deleted in 20 minutes. Timeout."
            exit 1
          fi
        done
      done
  else
    echo "No running instance(s) found"
  fi
fi

echo "Provisioning CA ..."
provisioningRequestResponse=""
#echo "Provisioning data:"
#echo "$(provision_data)"
provisioningRequestResponse=$(curl -v -k -H "Content-Type:application/json" \
      -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -X POST -d "$(provision_data)" ${cpd_web_url}/zen-data/v3/service_instances)
#echo "provisioningRequestResponse: ${provisioningRequestResponse}"
provisioningRequestStatus=$(jq -r '.status_code' <<< ${provisioningRequestResponse})
echo "provisioningRequestStatus: ${provisioningRequestStatus}"

if [[ ${provisioningRequestStatus} == "0" || ${provisioningRequestStatus} != "null" ]]; then
    echo "Provisioning of Instance failed."
    exit 1
fi

echo "Provisioning CA started  ...."
sleep 30
curl -v -k -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -H "Content-Type:application/json" \
    -X GET "${cpd_web_url}/zen-data/v3/service_instances?addon_type=cognos-analytics-app&addon_version=${addon_version}"

echo "Checking Status of the instance ..."
instanceId=$(jq -r '.id' <<< ${provisioningRequestResponse})
BuildTimeOutInMinutes=${provision_timeout}
minutesRemainingInTimeOut=${BuildTimeOutInMinutes}

while [ ${minutesRemainingInTimeOut} -gt 0 ]; do
  sleep 60
  let minutesRemainingInTimeOut-=1
  statusJSON=$(curl -k -b ${zen_cookie_file} --cookie "ibm-private-cloud-session=${bearer_auth_token}" -H "Content-Type:application/json" \
  -X GET "${cpd_web_url}/zen-data/v3/service_instances/${instanceId}?include_service_status=true")
#  echo "statusJSON: ${statusJSON}"
  instanceStatus=$(jq -r '.services_status' <<< ${statusJSON})
  provisionStatus=$(jq -r '.service_instance.provision_status' <<< ${statusJSON})
  echo "Current status of the instance: ${instanceStatus}"
  echo "Current status of the provisioning: ${provisionStatus}"
  let timeElapsed=${BuildTimeOutInMinutes}-${minutesRemainingInTimeOut}
  echo "Time elapsed: ${timeElapsed} minutes"
  if [[ ${instanceStatus} == "RUNNING" ]]; then
      echo "Instance Provisioned Successfully"
      exit 0
  elif [[ ${instanceStatus} == null ]]; then
      echo "Unable to get instance, terminating run."
      exit 1
  elif [[ ${provisionStatus} == "PROVISION_IN_PROGRESS" ]];then
      echo "Provision in Progress..."
  elif [[ ${provisionStatus} == "FAILED" ]];then
      echo "Provision FAILED!"
      exit 1
  else
      echo "Checking status of the instance..."
  fi
done

echo "Either provisioning of instance failed or it's been over ${BuildTimeOutInMinutes} minutes."
exit 1

#ls -la ${my_tmp_dir}
trap 'rm -rf -- "${my_tmp_dir}"; ' EXIT
