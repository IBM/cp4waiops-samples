#!/bin/bash
#
# © Copyright IBM Corp. 2024
#
# Use this script with IBM Cloud Pak for AIOps 4.3.0 and later to allow a
# Netcool Operations Insight probe to be connected to it.
# The script can be used on version 4.2.x before upgrading to 4.3.0 in order to
# ensure uninterrupted operation.
#
# Usage: ./enabled-netcool-integration.sh [-n namespace] [cp4aiops_name]
#
# The current namespace is used if the -n option is not used.
# cp4aiops_name defaults to ibm-cp-aiops.
#
namespace_opt=
name=ibm-cp-aiops
args=$(getopt n: $*)
if [ $? -ne 0 ]; then
    echo 'Usage: ./enabled-netcool-integration.sh [-n namespace] [cp4aiops_name]'
    exit 2
fi
set -- $args
while :; do
    case "$1" in
        -n)
            namespace_opt="-n $2"
            shift; shift
            ;;
        --)
            shift; break
            ;;
    esac
done
if [ $# -gt 0 ]; then
    name="$1"
fi

tool=oc
$tool version --client > /dev/null 2>&1
if [ $? -ne 0 ]; then
    tool=kubectl
    $tool version --client > /dev/null 2>&1
fi
if [ $? -ne 0 ]; then
    echo 'Either oc or kubectl must be installed'
    exit 2
fi

enable_deployments() {
    deployments=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{range .spec.pakModules[${ampos}].config[${ircpos}].spec.issueresolutioncore.customSizing.deployments[*]}{.name}{'\n'}{end}")
    if [ "x$deployments" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/deployments","value":[{"name":"ncodl-if","replicas":1}]}]'
        return
    fi

    deployment=$(echo "$deployments" | grep -n '^ncodl-if$')
    if [ "x$deployment" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/deployments/-","value":{"name":"ncodl-if","replicas":1}}]'
        return
    fi
    ifpos=$(expr $(echo "$deployment" | head -1 | sed 's/:.*//') - 1)

    $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/deployments/'$ifpos'/replicas","value":1}]'
}

enable_primary() {
    primary=$(echo "$statefulsets" | grep -n '^ncoprimary$')
    if [ "x$primary" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/statefulSets/-","value":{"name":"ncoprimary","replicas":1}}]'
        return
    fi
    primarypos=$(expr $(echo "$primary" | head -1 | sed 's/:.*//') - 1)

    $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/statefulSets/'$primarypos'/replicas","value":1}]'
}

enable_backup() {
    backup=$(echo "$statefulsets" | grep -n '^ncobackup$')
    if [ "x$backup" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/statefulSets/-","value":{"name":"ncobackup","replicas":1}}]'
        return
    fi
    backuppos=$(expr $(echo "$backup" | head -1 | sed 's/:.*//') - 1)

    $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/statefulSets/'$backuppos'/replicas","value":1}]'
}

enable_netcool_integration() {
    pakmodule=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{range .spec.pakModules[*]}{.name}{'\n'}{end}" | grep -n '^applicationManager$')
    if [ "x$pakmodule" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/-","value":{"name":"applicationManager","enabled":true,"config":[{"name":"ir-core-operator","spec":{"issueresolutioncore":{"customSizing":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}}}]}}]'
        return
    fi
    ampos=$(expr $(echo "$pakmodule" | head -1 | sed 's/:.*//') - 1)

    operators=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{range .spec.pakModules[${ampos}].config[*]}{.name}{'\n'}{end}")
    if [ "x$operators" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'${ampos}'/config","value":[{"name":"ir-core-operator","spec":{"issueresolutioncore":{"customSizing":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}}}]}]'
        return
    fi

    operator=$(echo "$operators" | grep -n '^ir-core-operator$')
    if [ "x$operator" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/-","value":{"name":"ir-core-operator","spec":{"issueresolutioncore":{"customSizing":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}}}}]'
        return
    fi
    ircpos=$(expr $(echo "$operator" | head -1 | sed 's/:.*//') - 1)

    spec=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{.spec.pakModules[${ampos}].config[${ircpos}].spec}")
    if [ "x$spec" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec","value":{"issueresolutioncore":{"customSizing":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}}}]'
        return
    fi

    issueresolutioncore=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{.spec.pakModules[${ampos}].config[${ircpos}].spec.issueresolutioncore}")
    if [ "x$issueresolutioncore" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore","value":{"customSizing":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}}]'
        return
    fi

    customsizing=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{.spec.pakModules[${ampos}].config[${ircpos}].spec.issueresolutioncore.customSizing}")
    if [ "x$customsizing" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing","value":{"deployments":[{"name":"ncodl-if","replicas":1}],"statefulSets":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}}]'
        return
    fi

    enable_deployments

    statefulsets=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{range .spec.pakModules[${ampos}].config[${ircpos}].spec.issueresolutioncore.customSizing.statefulSets[*]}{.name}{'\n'}{end}")
    if [ "x$statefulsets" = "x" ]; then
        $tool patch installations.orchestrator.aiops.ibm.com $namespace_opt $name --type=json --patch='[{"op":"add","path":"/spec/pakModules/'$ampos'/config/'$ircpos'/spec/issueresolutioncore/customSizing/statefulSets","value":[{"name":"ncoprimary","replicas":1},{"name":"ncobackup","replicas":1}]}]'
        return
    fi

    enable_primary

    enable_backup
}

check_custom_profile_not_in_use() {
    config_map_name=$($tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{.spec.resourceOverrides}")
    if [ "x$config_map_name" = "x" ]; then
        return
    fi

    config_map=$($tool get configmap -o name $config_map_name 2> /dev/null)
    if [ "x$config_map" != "x" ]; then
        printf "This tool cannot be used with resource override ConfigMap\n"
        printf "\n"
        printf "Installation $name is configured to use resource override ConfigMap $config_map_name.\n"
        printf "Please use the custom sizing tool to adjust ObjectServer and ncodl-if replica counts to 1.\n"
        exit 1
    fi
}

check_installation_exists() {
    $tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=name > /dev/null
    if [ $? -ne 0 ]; then
        exit 1
    fi
}

check_installation_exists

check_custom_profile_not_in_use

enable_netcool_integration

$tool get installations.orchestrator.aiops.ibm.com $namespace_opt $name -o=jsonpath="{range .spec.pakModules[?(@.name=='applicationManager')].config[?(@.name=='ir-core-operator')].spec.issueresolutioncore.customSizing['deployments','statefulSets'][*]}{.name}: {.replicas} replica(s){'\n'}{end}"
