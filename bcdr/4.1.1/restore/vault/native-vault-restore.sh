#!/bin/bash
#

# (C) Copyright IBM Corporation 2021-2023 All Rights Reserved.
# 
# 
#

## Assumptions:
# - You have oc/jq installed in the environment.
# - You already logged into the cluster as the admin.
# - This script only restores the backup for default VaultDeploy which is: ibm-vault-deploy

## Input Parameters:
# -n: the namespace of CP4WAIOps

#set -x

NS=cp4waiops

usage() {
echo Usage:
echo "  -n, --namespace,   the namespace of AIOps"
echo For example:
echo "  ${0} -n cp4waiops"
}
while true ; do
    case "$1" in
        -n|--namespace)
            export NS=$2
            if [ "$2" == "" ];
            then
                usage
                echo -e "\nFAIL: missing parameter for '--namespace'.\n"
                exit 1
            fi
            shift 2 ;;
        *)
            if [ "$1" != "" ];
            then
                usage
                exit 1
            fi
            break
            ;;
    esac
done

folder=$WORKDIR/restore/vault/ibm-vault-deploy-backup
# [ -n "$1" ] && folder=$1
deploy_folder=$(echo $folder | sed -e 's/.*\///')
deploy_cr=$(echo $deploy_folder | sed -e 's/-backup$//')
[ -d "$folder" ] || { echo Cannot find the specified directory $folder, exit ...; exit -1; }

echo Collecting information ...
cd $folder
[ ! -e backup.snap ] && echo Cannot find the snapshot backup.snap, exit ... && exit -1
[ ! -e bootstrap-token ] && echo Cannot find the bootstrap token bootstrap-token, exit ... && exit -1
[ ! -e secret-name ] && echo Cannot find the file secret-name, exit ... && exit -1
[ ! -e ibm-vault-deploy-consul-credential.json ] && echo Cannot find the file ibm-vault-deploy-consul-credential.json, exit ... && exit -1
[ ! -e ibm-vault-deploy-vault-config.json ] && echo Cannot find the file ibm-vault-deploy-vault-config.json, exit ... && exit -1
[ ! -e ibm-vault-deploy-vault-credential.yaml ] && echo Cannot find the file ibm-vault-deploy-vault-credential.yaml, exit ... && exit -1
[ ! -e ibm-vault-deploy-vault-keys.json ] && echo Cannot find the file ibm-vault-deploy-vault-keys.json, exit ... && exit -1
bs_token=$(cat bootstrap-token)
access_se=$(cat secret-name)

# get boostrap token from new cluster
bs_token_new=$(oc -n ${NS} get secret $deploy_cr-consul-credential --template='{{.data.bootstrapToken | base64decode}}')

# get consul leader pod
consulPod0=$deploy_cr-consul-0
consulPod1=$deploy_cr-consul-1
consulPod2=$deploy_cr-consul-2
consulLeaderPod=`oc exec -ti $consulPod0 -n ${NS} -- consul operator raft list-peers -token=$bs_token_new | grep leader | awk '{print $1}'`
[ -z "$consulLeaderPod" ] && echo Failed to get consul leader pod, exit ... && exit -1
echo "consul leader pod is: $consulLeaderPod"

echo Restore snapshot ...
oc -n ${NS} cp ./backup.snap $consulLeaderPod:tmp/backup.snap
[ $? -ne 0 ] && echo Failed to copy snapshot to the Consul pod $consulLeaderPod, exit ... && exit -1
oc -n ${NS} exec -i -t $consulLeaderPod -- consul snapshot restore -token=$bs_token_new /tmp/backup.snap
[ $? -ne 0 ] && echo Failed to restore snapshot to the Consul pod $consulLeaderPod, exit ... && exit -1

echo Restore Kubernetes objects ...
echo "Deleting old secrets"
oc -n ${NS} delete secret $deploy_cr-consul-credential $deploy_cr-vault-config $deploy_cr-vault-keys $access_se || true

echo "Removing ownerReferences for secret objects"
cat <<< $(jq 'del(.metadata.ownerReferences)' $deploy_cr-consul-credential.json) > $deploy_cr-consul-credential.json && \
cat <<< $(jq 'del(.metadata.ownerReferences)' $deploy_cr-vault-config.json) > $deploy_cr-vault-config.json && \
cat <<< $(jq 'del(.metadata.ownerReferences)' $deploy_cr-vault-keys.json) > $deploy_cr-vault-keys.json
[ $? -ne 0 ] && echo Failed to remove ownerReferences for $deploy_cr-consul-credential, $deploy_cr-vault-config, $deploy_cr-vault-keys, exit ... && exit -1

echo "Creating new secrets"
oc -n ${NS} create -f $deploy_cr-consul-credential.json && \
oc -n ${NS} create -f $deploy_cr-vault-config.json && \
oc -n ${NS} create -f $deploy_cr-vault-keys.json && \
oc -n ${NS} create -f $access_se.yaml
[ $? -ne 0 ] && echo Failed to restore secrets $deploy_cr-consul-credential, $deploy_cr-vault-config, $deploy_cr-vault-keys, and $access_se, exit ... && exit -1

echo Patch secret Vault credential ...
grep '^data:\|^  token:' $deploy_cr-vault-credential.yaml > patch.yaml
token=$(grep '^  token:' patch.yaml | awk '{print $2}')
[ -z "$token" ] && echo Failed to get value of token from $deploy_cr-vault-credential.yaml, exit ... && exit -1
oc -n ${NS} patch secret $deploy_cr-vault-credential --patch-file patch.yaml
[ $? -ne 0 ] && echo Failed to patch secret $deploy_cr-vault-credential, exit ... && exit -1

echo Execute post restoration steps ...
# determine if HA is enabled
profile=`oc -n ${NS} get vaultdeploy $deploy_cr -o jsonpath='{.spec.size}'`
# deregister consul pods
if [ $profile == "small" ]
then
  echo "HA is not enabled, deregistering consulPod0"
  oc -n ${NS} exec -i -t $consulLeaderPod -- curl -k --request PUT --header "X-CONSUL_HTTP_TOKEN: $bs_token" --data "{\"Datacenter\": \"dc1\", \"Node\": \"$consulPod0\"}" https://127.0.0.1:8501/v1/catalog/deregister
else
  echo "HA is enabled, deregistering consul pod0 pod1 pod2"
  oc -n ${NS} exec -i -t $consulLeaderPod -- curl -k --request PUT --header "X-CONSUL_HTTP_TOKEN: $bs_token" --data "{\"Datacenter\": \"dc1\", \"Node\": \"$consulPod0\"}" https://127.0.0.1:8501/v1/catalog/deregister
  oc -n ${NS} exec -i -t $consulLeaderPod -- curl -k --request PUT --header "X-CONSUL_HTTP_TOKEN: $bs_token" --data "{\"Datacenter\": \"dc1\", \"Node\": \"$consulPod1\"}" https://127.0.0.1:8501/v1/catalog/deregister
  oc -n ${NS} exec -i -t $consulLeaderPod -- curl -k --request PUT --header "X-CONSUL_HTTP_TOKEN: $bs_token" --data "{\"Datacenter\": \"dc1\", \"Node\": \"$consulPod2\"}" https://127.0.0.1:8501/v1/catalog/deregister
fi
[ $? -ne 0 ] && echo Failed to de-register the old consul node, exit ... && exit -1

# delete vault lock
oc -n ${NS} exec -i -t $consulLeaderPod -- consul kv delete -token=$bs_token vault/core/lock

# restart consul pods
echo "restart consul pods"
if [ $profile == "small" ]
then
  oc -n ${NS} delete pod $consulPod0
else
  oc -n ${NS} delete pod $consulPod0
  oc -n ${NS} delete pod $consulPod1
  oc -n ${NS} delete pod $consulPod2
fi

# restart vault pods
echo "restart vault pods"
if [ $profile == "small" ]
then
  oc -n ${NS} delete pod $deploy_cr-vault-0
else
  oc -n ${NS} delete pod $deploy_cr-vault-0
  oc -n ${NS} delete pod $deploy_cr-vault-1
  oc -n ${NS} delete pod $deploy_cr-vault-2
fi

[ $? -eq 0 ] && echo Done! Successfully restored the Vault data store. && exit 0
echo Failed to restart pod $deploy_cr-consul-0 or $deploy_cr-vault-0, exit ... && exit -1
