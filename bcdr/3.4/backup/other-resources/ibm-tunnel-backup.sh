#!/bin/bash

NS=cp4waiops
BACKUP_SCRIPT_FILE_NAME=restore-secure-tunnel.sh

usage() {
echo Usage:
echo "  -n, --namespace,   the namespace of you AIOps installed in."
echo "  -f, --file,        the file name that you will save the backup data in."
echo For example:
echo "  ${0}  -n cp4waiops"
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
        -f|--file)
            export BACKUP_SCRIPT_FILE_NAME=$2
            if [ "$2" == "" ];
            then
                usage
                echo -e "\nFAIL: missing parameter for '--file'.\n"
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

cat<<EOF> ${BACKUP_SCRIPT_FILE_NAME}
#!/bin/bash

usage() {
echo Usage:
echo "  -n, --namespace: the namespace of you AIOps"
echo For example:
echo "  \${0}  -n cp4waiops"
}

while true ; do
    case "\$1" in
        -n|--namespace)
            export NAMESPACE=\$2
            if [ "\$2" == "" ];
            then
                usage
                echo -e "\nFAIL: missing parameter for '--namespace'.\n"
                exit 1
            fi
            shift 2 ;;
        *)
            if [ "\$1" != "" ];
            then
                usage
                exit 1
            fi
            break
            ;;
    esac
done

if [ "\${NAMESPACE}" == "" ]; then
  usage
  exit 1
fi

echo "namespace="\${NAMESPACE}
EOF



echo "# TunnelConnections" >> ${BACKUP_SCRIPT_FILE_NAME}
echo "start backup TunnelConnection CRs..."
for CONNECTION in $(kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com --no-headers | awk '{print $1}')
do 
    ID=`kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o=jsonpath='{.status.id}'`
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    UUID=`kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o=jsonpath='{.status.uuid}'`
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    DOMAIN=`kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o=jsonpath='{.status.autoInstallConnector.cloudTunnelConnectorDomain.domain}'`
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    if [ "${DOMAIN}" == "" ]; then
        DOMAIN=`kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o=jsonpath='{.spec.connectorConfiguration.cloudTunnelConnectorDomain.domain}'`
        if [ "$?" != "0" ]; then
        echo "backup error"
        exit 1
        fi
    fi

    CONNECTORINFOS=`kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o json | jq '"connectorInfos\""+":[", "{\"id\":\"" + .status.connectorInfos[].id + "\"},", "],"'`
    CONNECTORINFOS=`echo $CONNECTORINFOS | sed 's/" "//g' | sed 's/\\\"/"/g' | sed 's/},],"/}],/g' | sed 's/"/\\\"/g'`

    echo >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "kubectl -n \${NAMESPACE} delete tunnelconnections.securetunnel.management.ibm.com $CONNECTION --ignore-not-found" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "cat <<EOF | kubectl -n \${NAMESPACE} apply -f -" >> ${BACKUP_SCRIPT_FILE_NAME}
    kubectl -n ${NS} get tunnelconnections.securetunnel.management.ibm.com $CONNECTION -o json | \
    jq 'del(.spec.connectorInfos,.metadata.namespace,.metadata.creationTimestamp,.metadata.managedFields,.metadata.annotations,.metadata.resourceVersion,.metadata.uid,.metadata.generation,.status)' | \
    jq ".spec += {\"id\": \"${ID}\"}" | \
    jq ".spec += {\"uuid\": \"${UUID}\"}" | \
    jq ".spec.connectorConfiguration.cloudTunnelConnectorDomain = {\"domain\": \"${DOMAIN}\", \"port\": 443}" | \
    sed "s/\"spec\": {/\"spec\": {\n    ${CONNECTORINFOS}/g" \
    >> ${BACKUP_SCRIPT_FILE_NAME}
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    echo "EOF" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "##" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "backup tunnel connection ${CONNECTION} successful"
done 
echo "all TunnelConnection CRs backup successful"
echo
echo

echo "##########" >> ${BACKUP_SCRIPT_FILE_NAME}
echo "# ApplicationMapping" >> ${BACKUP_SCRIPT_FILE_NAME}
echo "start backup ApplicaionMapping CRs..."
for APPLICATIONMAPPING in $(kubectl -n ${NS} get applicationmappings.securetunnel.management.ibm.com --no-headers | awk '{print $1}')
do 
    ID=`kubectl -n ${NS} get applicationmappings.securetunnel.management.ibm.com $APPLICATIONMAPPING -o=jsonpath='{.status.id}'`
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    echo "kubectl -n \${NAMESPACE} delete applicationmappings.securetunnel.management.ibm.com $APPLICATIONMAPPING --ignore-not-found" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "cat <<EOF | kubectl -n \${NAMESPACE} apply -f -" >> ${BACKUP_SCRIPT_FILE_NAME}
    kubectl -n ${NS} get applicationmappings.securetunnel.management.ibm.com $APPLICATIONMAPPING -o json | \
    jq 'del(.metadata.namespace,.metadata.creationTimestamp,.metadata.managedFields,.metadata.annotations,.metadata.resourceVersion,.metadata.uid,.metadata.generation,.status)' | \
    jq ".spec += {\"id\": \"${ID}\"}" \
    >> ${BACKUP_SCRIPT_FILE_NAME}
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi
    echo "EOF" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "##" >> ${BACKUP_SCRIPT_FILE_NAME}
    echo >> ${BACKUP_SCRIPT_FILE_NAME}
    echo "backup ApplicationMapping ${APPLICATIONMAPPING} successful"
done 
echo "all ApplicaionMapping CRs backup successful"
echo
echo

echo "# templates" >> ${BACKUP_SCRIPT_FILE_NAME}
echo "start backup templates CRs..."
for TEMPLATE in $(kubectl -n ${NS} get templates.securetunnel.management.ibm.com --no-headers | awk '{print $1}')
do 
    CREATOR=`kubectl -n ${NS} get templates.securetunnel.management.ibm.com $TEMPLATE -o=jsonpath='{.spec.creator}'`
    if [ "$?" != "0" ]; then
      echo "backup error"
      exit 1
    fi

    if [ "${CREATOR}" != "" ]; then
        echo "kubectl -n \${NAMESPACE} delete templates.securetunnel.management.ibm.com $TEMPLATE --ignore-not-found" >> ${BACKUP_SCRIPT_FILE_NAME}
        echo "cat <<EOF | kubectl -n \${NAMESPACE} apply -f -" >> ${BACKUP_SCRIPT_FILE_NAME}
        kubectl -n ${NS} get templates.securetunnel.management.ibm.com $TEMPLATE -o json | \
        jq 'del(.metadata.namespace,.metadata.creationTimestamp,.metadata.managedFields,.metadata.annotations,.metadata.resourceVersion,.metadata.uid,.metadata.generation,.status)' \
        >> ${BACKUP_SCRIPT_FILE_NAME}
        if [ "$?" != "0" ]; then
        echo "backup error"
        exit 1
        fi
        echo "EOF" >> ${BACKUP_SCRIPT_FILE_NAME}
        echo "##########" >> ${BACKUP_SCRIPT_FILE_NAME}
        echo "backup tunnel template ${TEMPLATE} successful"
    fi
done 
echo "all templates CRs backup successful"
echo
echo

chmod +x ${BACKUP_SCRIPT_FILE_NAME}
echo "secure tunnel backup successful"
