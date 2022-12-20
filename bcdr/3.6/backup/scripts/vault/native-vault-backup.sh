#!/bin/bash

## Assumptions:
# - You have oc/jq installed in the environment.
# - You already logged into the cluster as the admin.
# - This script backups the default CRs for VaultDeploy and VaultAccess, they are: ibm-vault-deploy and ibm-vault-access in aiops

## Input Parameters:
# -n: the namespace of CP4WAIOps

#set -x

uuid=$(cat /proc/sys/kernel/random/uuid)

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

echo Collecting information ...

deploy_cr=ibm-vault-deploy
# [ -n "$1" ] && deploy_cr=$1
oc -n ${NS} get vaultdeploys.vault.aiops.ibm.com $deploy_cr -o yaml > /tmp/vault.$uuid || { echo Cannot find VaultDeploy $deploy_cr in current namespace, exit ...; exit -1; }

access_cr=ibm-vault-access
# [ -n "$2" ] && access_cr=$2
oc -n ${NS} get vaultaccesses.vault.aiops.ibm.com $access_cr -o yaml > /tmp/access.$uuid || { echo Cannot find VaultAccess $access_cr in current namespace, exit ...; exit -1; }

mkdir -p $deploy_cr-backup
access_se=`oc get vaultaccess $access_cr -n ${NS} -o=jsonpath='{.spec.secretName}'`
[ -z "$access_se" ] && echo Failed to get secretName from VaultAccess $access_cr, exit ... && exit -1
echo $access_se > $deploy_cr-backup/secret-name
bs_token=$(oc -n ${NS} get secret $deploy_cr-consul-credential --template='{{.data.bootstrapToken | base64decode}}')
[ $? -ne 0 ] && echo Failed to get the bootstrap token, exit ... && exit -1
echo $bs_token > $deploy_cr-backup/bootstrap-token

# get consul leader pod
consulPod0=$deploy_cr-consul-0
consulLeaderPod=`oc exec -ti $consulPod0 -n ${NS} -- consul operator raft list-peers -token=$bs_token | grep leader | awk '{print $1}'`
[ -z "$consulLeaderPod" ] && echo Failed to get consul leader pod, exit ... && exit -1
echo "consul leader pod is: $consulLeaderPod"

echo Back up Consul ...
cd $deploy_cr-backup
oc -n ${NS} exec -i -t $consulLeaderPod -- consul snapshot save -token=$bs_token /tmp/backup.snap && oc -n ${NS} cp $consulLeaderPod:tmp/backup.snap ./backup.snap
[ $? -ne 0 ] && echo Failed to make and copy snapshot from the Consul pod $consulLeaderPod, exit ... && exit -1

echo Back up Kubernetes objects ...
oc -n ${NS} get secret $deploy_cr-consul-credential -o json > $deploy_cr-consul-credential.json && \
oc -n ${NS} get secret $deploy_cr-vault-keys -o json > $deploy_cr-vault-keys.json && \
oc -n ${NS} get secret $deploy_cr-vault-config -o json > $deploy_cr-vault-config.json && \
oc -n ${NS} get secret $deploy_cr-vault-credential -o yaml > $deploy_cr-vault-credential.yaml && \
oc -n ${NS} get secret $access_se -o yaml > $access_se.yaml
[ $? -eq 0 ] && echo Done! Successfully back up Vault $deploy_cr. && exit 0
echo Failed to back up Kubernetes objects, exit ... && exit -1