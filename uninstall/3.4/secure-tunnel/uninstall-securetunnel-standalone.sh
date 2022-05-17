#!/bin/bash

usage() {
   cat<<EOF
   This script is used to uninstall the Secure Tunnel as a standalone installation and can also be used to uninstall the Tunnel connector.

-t, --type <server|connector>,                              --type server: delete the server side of secure tunnel, --type connector: delete the connector side of the secure tunnel, by default is --type server
-n, --namespace <namespace>,                                the namespace of the tunnel server or tunnel connector
-c, --connection-name <the name of the tunnel connection>,  the name of the Secure tunnel connection that you want to uninstall
-h, --help,                           for help

For example:
    uninstall tunnel server:
        ${0}  --namespace cp4waiops
    uninstall tunnel connector from cluster(OpenShift or kubernetes):
        ${0} --type connector  --namespace tunnel-connector --connection-name connection-name
    uninstall tunnel connector from Host machine(VM or physical machine):
        ${0} --type connector --connection-name connection-name
EOF
}

TYPE=server

while true ; do
    case "$1" in
        -t|--type) 
            export TYPE=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        -n|--namespace)
            export NAMESPACE=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        -c|--connection-name)
            export CONNECTOR_NAME=$2
            if [ "$2" == "" ]; 
            then
                usage
                exit 1
            fi
            shift 2 ;;
        -h|--help)
            usage
            exit 0 
            ;;

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



if [ "${TYPE}" == "connector" ]; then

    if [ "${CONNECTOR_NAME}" == "" ]; then
        usage
        exit 1
    fi

    if [ "${NAMESPACE}" == "" ]; then
        echo "Deleting the Secure tunnel connector resources from VM"
        echo -e "\nchecking whether docker or podman is installed ..."

        if [ $( command -v docker ) ]
        then
            CMD=docker
        elif [ $( command -v podman ) ]
        then
            CMD=podman
        else
            echo -e "\nEither docker or podman is not found. "
            echo "Please make sure docker or podman is installed and try again."
            exit 1
        fi

        echo "$CMD found."

        find_connector="false"
        for CONTAINER_NAME in `docker ps | grep secure-tunnel-connector | awk '{print $1}'`;
        do
            str=`docker exec -it ${CONTAINER_NAME} env | grep CONNECTION_NAME`
            str=`echo $str | sed 's/[\r]*$//g'`
            name=${str:16}
            if [ "${name}" == "${CONNECTOR_NAME}" ]; then
                ${CMD} stop ${CONTAINER_NAME}
                echo "stop container ${CONTAINER_NAME}"
                ${CMD} rm ${CONTAINER_NAME}
                echo "rm container ${CONTAINER_NAME}"
                find_connector="true"
            fi
        done
        if [ "${find_connector}" == "true" ]; then
            echo "uninstall tunnel connector ${CONNECTOR_NAME} from Host machine successful"
        else
            echo "not found tunnel connector ${CONNECTOR_NAME} from Host machine"
        fi
    else
        echo "checking whether kubuctl or oc exists ..."
        if [ $( command -v oc ) ]
        then
            KUBECTL=oc
            $KUBECTL project
        elif [ $( command -v kubectl ) ]
        then
            KUBECTL=kubectl
        else
            echo "Either kubectl or oc is not found. "
            echo "Please make sure kubectl or oc is installed and try again."
            exit 1
        fi

        echo "$KUBECTL found."
        echo "uninstall Secure tunnel connector resources from cluster in namespace ${NAMESPACE} ..."

        CLUSTER_ENV=OpenShift
        ${KUBECTL} get route  > /dev/null
        RET=$?
        if [ "${RET}" != "0" ];
        then
            if [ -z "$debug" ]; then 
                rm -rf ./tunnel-connector-temp.yaml
            fi
            CLUSTER_ENV=kubernetes
        fi

        ${KUBECTL} get all -n ${NAMESPACE}

        for SERVICE_NAME in `${KUBECTL} -n ${NAMESPACE} get service -l tunnel_connection_name=${CONNECTOR_NAME} | awk '{print $1}'`;
        do
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found service ${SERVICE_NAME}
        done
        for NETWORKPOLICY_NAME in `${KUBECTL} -n ${NAMESPACE} get NetworkPolicy -l tunnel_connection_name=${CONNECTOR_NAME} | awk '{print $1}'`;
        do
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found NetworkPolicy ${NETWORKPOLICY_NAME}
        done
        for ROUTE_NAME in `${KUBECTL} -n ${NAMESPACE} get route -l tunnel_connection_name=${CONNECTOR_NAME} | awk '{print $1}'`;
        do
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found route ${ROUTE_NAME}
        done
        for INGRESS_NAME in `${KUBECTL} -n ${NAMESPACE} get ingress -l tunnel_connection_name=${CONNECTOR_NAME} | awk '{print $1}'`;
        do
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found ingress ${INGRESS_NAME}
        done

        find_connector="false"
        deployType="statefulset"
        for DEPLOY_NAME in `${KUBECTL} -n ${NAMESPACE} get ${deployType} -l tunnel_connection_name=${CONNECTOR_NAME} | grep tunnel | awk '{print $1}'`;
        do
            find_connector="true"
            RELEASE_NAME=`${KUBECTL} -n ${NAMESPACE} get ${deployType} ${DEPLOY_NAME} -o=jsonpath={.metadata.labels.'tunnel_release_name'}`
            TUNNEL_NETWORKID=`${KUBECTL} -n ${NAMESPACE} get ${deployType} ${DEPLOY_NAME} -o=jsonpath={.metadata.labels.'tunnel_connection_id'}`
            REPLICAS=`${KUBECTL} -n ${NAMESPACE} get ${deployType} ${DEPLOY_NAME} -o=jsonpath={.spec.replicas}`


            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found ${deployType} ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-connector
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found Secret ${RELEASE_NAME}-${TUNNEL_NETWORKID}-config
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found Service tunnel-dns-server
            ${KUBECTL} delete --ignore-not-found clusterrole ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-cluster
            ${KUBECTL} delete --ignore-not-found clusterrolebinding ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-cluster

            if [ "${CLUSTER_ENV}" == "OpenShift" ]; then
                ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found route ${RELEASE_NAME}-${TUNNEL_NETWORKID}-aiops-portforward
            else
                ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found ingress ${RELEASE_NAME}-${TUNNEL_NETWORKID}-aiops-portforward
            fi

            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found ServiceAccount ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-connector
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found Role ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-connector
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found RoleBinding ${RELEASE_NAME}-${TUNNEL_NETWORKID}-tunnel-connector
            ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found Service ${RELEASE_NAME}-${TUNNEL_NETWORKID}-svc


            NetworkPolicies=$( ${KUBECTL} -n ${NAMESPACE} get NetworkPolicy -o name )
            if [ -n "$NetworkPolicies" ]; then
                for i in $( ${KUBECTL} -n ${NAMESPACE} get NetworkPolicy -o name | grep ${RELEASE_NAME}-${TUNNEL_NETWORKID} )
                do 
                    ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found $i
                done
            fi

            Secrets=$( ${KUBECTL} -n ${NAMESPACE} get NetworkPolicy -o name )
            if [ -n "$Secrets" ]; then
                for i in $( ${KUBECTL} -n ${NAMESPACE} get Secret -o name | grep ${RELEASE_NAME}-${TUNNEL_NETWORKID} )
                do 
                    ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found $i
                done
            fi 

            Indexes=0
            while [ $Indexes -le $((REPLICAS-1)) ]
            do
                ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found Service ${RELEASE_NAME}-${TUNNEL_NETWORKID}-svc-${Indexes}
                if [ "${CLUSTER_ENV}" == "OpenShift" ]; then
                    ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found route c${TUNNEL_NETWORKID}${Indexes}
                    echo "removed route" c${TUNNEL_NETWORKID}${Indexes}
                else
                    ${KUBECTL} -n ${NAMESPACE} delete --ignore-not-found ingress c${TUNNEL_NETWORKID}${Indexes}
                    echo "removed ingress" c${TUNNEL_NETWORKID}${Indexes}
                fi


                Indexes=`expr $Indexes + 1`
            done #end while [ $Indexes -le $((REPLICAS-1)) ]
        done #end for DEPLOY_NAME in 

        if [ "${find_connector}" == "true" ]; then
            echo "uninstall tunnel connector ${CONNECTOR_NAME} from namespace ${NAMESPACE} successful"
        else
            echo "not found tunnel connector ${CONNECTOR_NAME} from namespace ${NAMESPACE}"
        fi
    fi #end if [ "${NAMESPACE}" == "" ]; then
else
    echo "checking whether kubuctl or oc exists ..."
    if [ $( command -v oc ) ]
    then
        KUBECTL=oc
        $KUBECTL project
    elif [ $( command -v kubectl ) ]
    then
        KUBECTL=kubectl
    else
        echo "Either kubectl or oc is not found. "
        echo "Please make sure kubectl or oc is installed and try again."
        exit 1
    fi
    echo "$KUBECTL found."

    if [ "${NAMESPACE}" == "" ]; then
        usage
        exit 1
    fi
    echo "uninstall the Secure tunnel server resources in $NAMESPACE "
    $KUBECTL -n $NAMESPACE delete tunnelconnections.securetunnel.management.ibm.com --all --ignore-not-found
    $KUBECTL -n $NAMESPACE delete applicationmappings.securetunnel.management.ibm.com --all --ignore-not-found
    $KUBECTL -n $NAMESPACE delete templates.securetunnel.management.ibm.com --all --ignore-not-found

    $KUBECTL -n $NAMESPACE delete tunnelconnections.tunnel.management.ibm.com --all --ignore-not-found
    $KUBECTL -n $NAMESPACE delete applicationmappings.tunnel.management.ibm.com --all --ignore-not-found
    $KUBECTL -n $NAMESPACE delete templates.tunnel.management.ibm.com --all --ignore-not-found

    $KUBECTL -n $NAMESPACE delete tunnels.sretooling.management.ibm.com --all --ignore-not-found

    CLUSTER_ROLE_NAME=`$KUBECTL -n $NAMESPACE get ClusterRole --ignore-not-found | grep $NAMESPACE-tunnel-cluster | awk '{print $1}'`
    if [ "${CLUSTER_ROLE_NAME}" != "" ]; then
        $KUBECTL -n $NAMESPACE delete ClusterRole $CLUSTER_ROLE_NAME --ignore-not-found
    fi

    for CLUSTER_ROLE_BIND_NAME in `$KUBECTL -n $NAMESPACE get ClusterRoleBinding --ignore-not-found | grep $NAMESPACE-tunnel-cluster | awk '{print $1}'`;
    do
        $KUBECTL -n $NAMESPACE delete ClusterRoleBinding $CLUSTER_ROLE_BIND_NAME --ignore-not-found
    done

    $KUBECTL -n $NAMESPACE delete subscription ibm-secure-tunnel-operator --ignore-not-found

    CSV_NAME=`$KUBECTL -n $NAMESPACE get csv --ignore-not-found | grep ibm-secure-tunnel | awk '{print $1}'`
    if [ "${CSV_NAME}" != "" ]; then
        $KUBECTL -n $NAMESPACE delete csv ${CSV_NAME} --ignore-not-found
    fi

    # delete the TLS certificate k8s secret that generated by the cert manager
    $KUBECTL -n $NAMESPACE delete secret `$KUBECTL -n $NAMESPACE get secret | grep 'sre-tunnel[0-9|a-z|-]*cert' | awk '{print $1}'` --ignore-not-found

    echo "check if there have another Secure tunnel operator reference to the Secure Tunnel CRDs"
    FIND_FLAG=false
    for TUNNEL_OPERATOR_NAMESPACE in `$KUBECTL get deployment -A | grep ibm-secure-tunnel-operator |  awk '{print $1}'`
    do
        if [ "${TUNNEL_OPERATOR_NAMESPACE}" != "${NAMESPACE}" ]; then
            FIND_FLAG=true
        fi
    done
    if [ "${FIND_FLAG}" == "false" ]; then
        echo "No other Secure tunnel operator reference to the Secure tunnel CRDs, deleteing them "
        $KUBECTL delete crd tunnelconnections.securetunnel.management.ibm.com --ignore-not-found
        $KUBECTL delete crd applicationmappings.securetunnel.management.ibm.com --ignore-not-found
        $KUBECTL delete crd templates.securetunnel.management.ibm.com --ignore-not-found

        $KUBECTL delete crd tunnelconnections.tunnel.management.ibm.com --ignore-not-found
        $KUBECTL delete crd applicationmappings.tunnel.management.ibm.com --ignore-not-found
        $KUBECTL delete crd templates.tunnel.management.ibm.com --ignore-not-found

        $KUBECTL delete crd tunnels.sretooling.management.ibm.com --ignore-not-found

        $KUBECTL delete ServiceAccount ibm-secure-tunnel-operator --ignore-not-found

        for ROLE_NAME in `$KUBECTL -n $NAMESPACE get Role --ignore-not-found | grep ibm-secure-tunnel | awk '{print $1}'`;
        do
            $KUBECTL -n $NAMESPACE delete Role $ROLE_NAME --ignore-not-found
        done
        for ROLE_NAME in `$KUBECTL get ClusterRole --ignore-not-found | grep ibm-secure-tunnel | awk '{print $1}'`;
        do
            $KUBECTL delete ClusterRole $ROLE_NAME --ignore-not-found
        done

        for ROLE_BIND_NAME in `$KUBECTL -n $NAMESPACE get RoleBinding --ignore-not-found | grep ibm-secure-tunnel | awk '{print $1}'`;
        do
            $KUBECTL -n $NAMESPACE delete RoleBinding $ROLE_BIND_NAME --ignore-not-found
        done
        for ROLE_BIND_NAME in `$KUBECTL get ClusterRoleBinding --ignore-not-found | grep ibm-secure-tunnel | awk '{print $1}'`;
        do
            $KUBECTL delete ClusterRoleBinding $ROLE_BIND_NAME --ignore-not-found
        done
    fi

    echo "uninstall tunnel server from namespace ${NAMESPACE} successful"
fi

echo "done"
