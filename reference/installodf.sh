#!/bin/bash
#
# © Copyright IBM Corp. 2022, 2024
# SPDX-License-Identifier: Apache2.0
#
# This reference script can be used to quickly install ODF as publicly
#   documented by Red Hat with reasonable default values and some customization.
#
# This script automates the manual instructions found here:
#   https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/4.15/html-single/deploying_openshift_data_foundation_using_bare_metal_infrastructure/index
# 
# The script can be used in a production environment, but is not a substitute
#   for thorough planning or an understanding of the installation process and
#   its consequences.
#
# Minimal Resource Requirements:
#   - https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/4.15/html-single/planning_your_deployment/index#resource-requirements_rhodf
#   - Capacity Planning: https://access.redhat.com/labs/ocsst/?p=BareMetal
#   - Minimum ODF resource requirements (as of 4.15) per node:
#     - 10 CPU
#     - 24Gi memory
#     - 100Gi Disk storage (but considerably more for applications and cluster)
#   - Minimum Disk Storage for AIOps:
#     - https://www.ibm.com/docs/en/cloud-paks/cloud-pak-aiops/latest?topic=planning-hardware-requirements#aimgr_storage
#     - Starter: 1800GB = (500 disk + 100 OCP monitoring) * 3 ODF replicas
#     - Production:  6600GB = (2000 disk + 200 OCP monitoring) * 3 ODF replicas
#   - Examples:
#     - Starter:    1TB worker0, 1TB worker1, 1TB worker2
#     - Production: 3TB worker0, 3TB worker1, 3TB worker2
#
# Configurable environment variables and their default values:
#   - ODF_NODE_COUNT=3
#       The number of worker nodes to use for ODF, this script will attempt to
#       use the ones with the most disk discovered.
#   - OCP_LOCAL_STORAGE_NODE_LABEL=node-role.kubernetes.io/worker
#       Node label for worker nodes used for ODF. Set this to explicitly tell
#       the script where to install ODF instead of attempting to auto discover
#       which nodes have the most disk space
#   - ODF_DEDICATED_NODE
#       Set this to any value to mark each ODF node as dedicated solely to ODF
#       (recommended by RedHat, but fine to not set for non-production environments
#       if licensing is not an issue). For details:
#       https://access.redhat.com/documentation/en-us/red_hat_openshift_data_foundation/4.15/html-single/managing_and_allocating_storage_resources/index#how-to-use-dedicated-worker-nodes-for-openshift-data-foundation_rhodf
#   - ODF_DEVICE_PATHS
#       A comma separated list of block disks to use for local storage
#         - /dev/odf/localstorage or /dev/vdb,/dev/vdc or /dev/sdb,/dev/sdc or /dev/hdb,/dev/hdc
#       NOTE:
#         - Whitespaces are not allowed
#         - ODF uses more CPU and memory for each path found. Consider using an LVM
#           or some other means of presenting a single path to OCP local storage
#         - https://docs.openshift.com/container-platform/4.15/storage/persistent_storage/persistent_storage_local/persistent-storage-local.html
#   - ODF_DEVICE_TYPES=disk
#       A comma separated list of types of devices ODF should search for on the
#       nodes.  The valid values are:
#         - disk  (unused raw disk)
#         - part  (unused raw partition)
#         - loop  (loop device)
#         - mpath (multipath)
#       NOTE:
#         - RedHat documents that LVM devices are not supported if you use this feature
#         - ODF uses more CPU and memory for this "auto discover" feature that
#           does not go away once PVs are found and created.  If resources are
#           tight, consider using ODF_DEVICE_PATHS
#   - ODF_MAX_DEVICE_COUNT
#       When used with ODF auto discovery (ODF_DEVICE_TYPES env var), for every
#       node "found" with disks, limit the maximum number of devices used for
#       ODF. It's not clear what algorithm they use (e.g. first found, most
#       storage, etc).
#   - ODF_ON_CONTROL_PLANE
#       Use with caution.  Set this to the control plane taint used to allow ODF
#       (and therefore LocalStorage) to run on control plane nodes.  This is not
#       recommended for most environments, only set this when aware of the
#       consequences.
#       oc get no -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[0].spec.taints[*]}{@.key}{"\n"}{end}' | grep '^node-role.kubernetes.io/'
#   - CHANNEL_LOCAL_STORAGE=stable
#       Deprecated legacy option for older versions that did not support stable
#
# Guidelines:
#   - Consider using the first or last 3 (or more) worker nodes in your cluster
#     and add disk to just those nodes.  Spreading ODF to use all nodes can
#     deplete CPU and memory.
#   - To help minimize the resources required for ODF, keep the local disk device
#     count minimum.
#     For example:  Instead of 2 devices of 1TB, have 1 device of 2TB, this will
#       save 2CPU and 5GB RAM (as of 4.15) for each disk device.
#   - Setting ODF_MAX_DEVICE_COUNT can help if for some reason there are "extra"
#     block devices, but if they are not uniform, the largest might not
#     be used. For storage configurations that are not simple raw devices,
#     manually edit the LocalVolumeSet deviceInclusionSpec below. (See the
#     Red Hat documentation above for details)
#
# ODF Debug commands:
#  https://github.com/openshift/runbooks/blob/master/alerts/openshift-container-storage-operator/helpers/troubleshootCeph.md
#    oc exec -n openshift-storage $(oc get pods -n openshift-storage -o name -l app=rook-ceph-operator) --
#  Append to above one or more commands:
#    ceph status -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd status -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd tree -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd df tree -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd utilization -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd pool stats -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph pg stat -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph df -c /var/lib/rook/openshift-storage/openshift-storage.config
#    ceph osd dump -c /var/lib/rook/openshift-storage/openshift-storage.config | grep ocs-storagecluster-cephblockpool
#
# MustGather: https://www.ibm.com/support/pages/node/6980807:
#
# If/When you need additional ceph tools for debugging ODF:
# oc patch storagecluster ocs-storagecluster -n openshift-storage --type merge -p '{"spec":{"enableCephTools":true}}'

#set -x

#Customization
nc=$(oc get no --no-headers --ignore-not-found -l cluster.ocs.openshift.io/openshift-storage | wc -l)
if [[ $nc -ge 3 ]]; then
  echo INFO: Found $nc nodes already labelled for ODF, using them
  ODF_NODE_COUNT=$nc
  OCP_LOCAL_STORAGE_NODE_LABEL=cluster.ocs.openshift.io/openshift-storage
elif [[ $nc -gt 0  &&  $nc -lt 3 ]]; then
  echo ERROR: $nc nodes labelled for ODF, but need at least 3
  exit 1
else
  if [[ -z "${OCP_LOCAL_STORAGE_NODE_LABEL}" ]]; then
    OCP_LOCAL_STORAGE_NODE_LABEL=node-role.kubernetes.io/worker
    echo INFO: OCP_LOCAL_STORAGE_NODE_LABEL not set using ${OCP_LOCAL_STORAGE_NODE_LABEL}
  fi
  nc=$(oc get --no-headers node -l ${OCP_LOCAL_STORAGE_NODE_LABEL} | wc -l)
  if [[ $nc -lt 1 ]]; then
    echo ERROR: No nodes matched label ${OCP_LOCAL_STORAGE_NODE_LABEL}
    exit 1
  fi
  if [[ -z "${ODF_NODE_COUNT}" ]]; then ODF_NODE_COUNT=3; fi
  echo ${ODF_NODE_COUNT} | egrep -q '^[0-9]+$'
  if [[ $? -ne 0 ]]; then
    echo ERROR: ODF_NODE_COUNT must be a positive integer not ${ODF_NODE_COUNT}
    exit 1
  fi
  if [[ $ODF_NODE_COUNT -lt 3 ]]; then
    echo ERROR: ODF_NODE_COUNT is $ODF_NODE_COUNT but cannot be less than 3
    exit 1
  fi
  if [[ $nc -lt $ODF_NODE_COUNT ]]; then
    echo ERROR: $nc nodes labelled ${OCP_LOCAL_STORAGE_NODE_LABEL} is less than \
         ODF_NODE_COUNT of ${ODF_NODE_COUNT}
    exit 1
  fi
fi
if [[ -n "${ODF_MAX_DEVICE_COUNT}" ]]; then   #devices on node
  max_dev_field="maxDeviceCount: ${ODF_MAX_DEVICE_COUNT}"  
# else the default is to use all
fi
if [[ -z "${CHANNEL_LOCAL_STORAGE}" ]]; then
  CHANNEL_LOCAL_STORAGE=stable
fi

ODF_DEVICE_PATHS=$(echo ${ODF_DEVICE_PATHS} | sed -r 's/[ ,]*$//; s/[ ,]+/,/g')
b=$(echo ${ODF_DEVICE_PATHS} | egrep '\s')
if [[ -n "$b" ]]; then
  echo ODF_DEVICE_PATHS connot contain whitespace: \"$b\"
  exit $LINENO
fi

: "${ODF_DEVICE_TYPES:=disk}"
ODF_DEVICE_TYPES=$(echo ${ODF_DEVICE_TYPES} | sed -r 's/[ ,]*$//; s/[ ,]+/, /g')
b=$(echo ${ODF_DEVICE_TYPES} | sed 's/, /\n/g' | egrep -v '^disk$|^part$|^loop$|^mpath$')
if [[ -n "$b" ]]; then
  echo ODF_DEVICE_TYPES has incorrect values: $b
  echo ODF_DEVICE_TYPES values can be any of disk, part, loop, mpath
  exit $LINENO
fi


function discover_disks {
  if [[ -n "${ODF_DEVICE_PATHS}" ]]; then
    for n in $(oc get no -l ${OCP_LOCAL_STORAGE_NODE_LABEL} -o jsonpath='{.items[*].metadata.name}'); do
      echo $(oc debug node/$n -- chroot /host bash -c 'lsblk -b $(realpath '${ODF_DEVICE_PATHS}' 2>/dev/null) /dev/null 2>/dev/null \
      | tail -n +2 | awk '\''BEGIN{s=0}{s+=($4/1048576)}END{print s}'\') $n
    done
  else
    for d in $(oc get -n openshift-local-storage localvolumediscoveryresults -o custom-columns=:.metadata.name); do
      s=$((($(oc get -n openshift-local-storage localvolumediscoveryresults $d -o jsonpath='{@.status.discoveredDevices[?(@.status.state=="Available")].size}' | sed 's/ /+/g' | sed 's/^$/0/')+0)/1048576))
      oc get -n openshift-local-storage localvolumediscoveryresults $d -o jsonpath=$s' {.spec.nodeName}{"\n"}'
    done
  fi
}


echo Installing Local Storage
cat << EOF | oc apply --validate -f -
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: openshift-local-storage
  labels:
    openshift.io/cluster-monitoring: "true"
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: local-operator-group
  namespace: openshift-local-storage
spec:
  targetNamespaces:
  - openshift-local-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: local-storage-operator
  namespace: openshift-local-storage
spec:
  channel: "${CHANNEL_LOCAL_STORAGE}"
  installPlanApproval: Automatic
  name: local-storage-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  config:
    tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
      effect: NoSchedule
EOF


echo -n 'Waiting for Local Storage to be installed...'
while true; do
  sleep 5;
  s=$(oc get csvs -n openshift-local-storage -o jsonpath='{.items[?(@.spec.displayName=="Local Storage")].status.phase}')
  if [[ "${s}" == "Succeeded" ]]; then break; fi
  echo -n .
done
echo done

oc get csvs -n openshift-local-storage
echo


echo Installing ODF...
OCP_CH=$(oc version -o yaml | sed -n 's/^openshiftVersion:  *\([^.]*\.[^.]*\)\..*/\1/p')

cat << EOF | oc apply --validate -f -
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: openshift-storage
  labels:
    openshift.io/cluster-monitoring: "true"
spec: {}
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
  - openshift-storage
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: stable-${OCP_CH}
  installPlanApproval: Automatic
  name: odf-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  config:
    tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
      effect: NoSchedule
EOF

echo -n 'Waiting for ODF to be installed...'
while true; do
  sleep 5;
  s=$(oc get csvs -n openshift-storage -o jsonpath='{.items[?(@.spec.displayName=="OpenShift Data Foundation")].status.phase}')
  if [[ "${s}" == "Succeeded" ]]; then break; fi
  echo -n .
done
echo done

#Enable ODF console plugin to view stats and status when necessary
p=$(oc get console.operator cluster -o jsonpath='{.spec.plugins[?(@=="odf-console")]}')
if [[ -z "$p" ]]; then
  oc patch console.operator cluster --type json -p '[{"op": "add", "path": "/spec/plugins/0", "value": "odf-console"}]'
fi

oc get csvs -n openshift-storage
echo


localvolume=$(oc get --ignore-not-found LocalVolume ocs-local-block -o jsonpath='{.metadata.name}')
if [[ -n "${localvolume}" ]]; then
  if [[ -z "${ODF_DEVICE_PATHS}" ]]; then
    if [[ -z "$(oc get --ignore-not-found LocalVolumeDiscovery auto-discover-devices -o jsonpath='{.metadata.name}')" ]]; then
      echo "ERROR: Refusing to use auto-discovery when ODF was previously configured without it."
      echo "       This will likely result in data loss"
      exit $LINENO 
    fi
  fi
fi


if [[ -z "${ODF_DEVICE_PATHS}" ]]; then
  #OCP ODF/LocalStorage Auto discovery mode

  #Create local storage where we can even if ODF can't/won't use it
  cat << EOF | oc apply --validate -f -
apiVersion: local.storage.openshift.io/v1alpha1
kind: LocalVolumeDiscovery
metadata:
 name: auto-discover-devices
 namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: ${OCP_LOCAL_STORAGE_NODE_LABEL}
        operator: Exists
  tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
EOF

  if [[ -n "${ODF_ON_CONTROL_PLANE}" ]]; then
    oc patch LocalVolumeDiscovery auto-discover-devices --type json -p \
      '[{"op": "add", "path": "/spec/tolerations/1", "value": "{"key":"'${ODF_ON_CONTROL_PLANE}'", "operator":"Exists"}}]'
  fi

  echo -n Waiting for LocalVolumeDiscoveryResults...
  while true; do
    s=$(oc get localvolumediscovery auto-discover-devices -n openshift-local-storage -o jsonpath='{.status.conditions[?(@.type=="Available")].status}')
    if [[ "${s}" == "True" ]]; then break; fi
    echo -n .
    sleep 5;
  done
  echo done
  oc get -n openshift-local-storage -o wide localvolumediscoveryresults
fi

if [[ "${OCP_LOCAL_STORAGE_NODE_LABEL}" != "cluster.ocs.openshift.io/openshift-storage" ]]; then

  #label first ODF_NODE_COUNT nodes with local storage that has the most storage
  echo
  echo INFO: Labeling nodes for ODF with the most disk
  while read n; do
    oc label --overwrite node $n cluster.ocs.openshift.io/openshift-storage=''
  done< <(discover_disks | sort -k1rn -k2 | head -${ODF_NODE_COUNT} | awk '{print $2}')
  nc=$(oc get no --ignore-not-found --no-headers -l cluster.ocs.openshift.io/openshift-storage | wc -l)
  if [[ $nc -lt ${ODF_NODE_COUNT} ]]; then
    echo ERROR: Only discovered $nc nodes but ODF_NODE_COUNT is set to ${ODF_NODE_COUNT}
    exit 2
  fi
fi

echo
echo INFO: Labeling ODF nodes as infrastructure
for n in $(oc get no -l cluster.ocs.openshift.io/openshift-storage --no-headers -o custom-columns=:.metadata.name); do
  oc label --overwrite node $n node-role.kubernetes.io/infra='' 
  if [[ -n "${ODF_DEDICATED_NODE}" ]]; then
    oc adm taint node $n node.ocs.openshift.io/storage="true":NoSchedule
  fi
done

#Now that storage nodes are labeled, put the storage operators on those nodes too
for s in $(oc get Subscription -n openshift-local-storage -o jsonpath='{.items[*].metadata.name}'); do
  oc patch Subscription $s -n openshift-local-storage --type json \
     -p '[{"op": "add", "path": "/spec/config/nodeSelector", "value": {"cluster.ocs.openshift.io/openshift-storage": ""}}]'
done
#TODO: patch only the ODF subscriptions 
for s in $(oc get Subscription -n openshift-storage -o jsonpath='{.items[*].metadata.name}'); do
  oc patch Subscription $s -n openshift-storage --type json \
     -p '[{"op": "add", "path": "/spec/config/nodeSelector", "value": {"cluster.ocs.openshift.io/openshift-storage": ""}}]'
done
echo
echo ODF nodes:
oc get no -l cluster.ocs.openshift.io/openshift-storage
echo



if [[ -z "${ODF_DEVICE_PATHS}" ]]; then
  #ODF auto discovery mode

  #Must create LocalVolumeSet exclusively for ODF otherwise ODF will run on all
  #  nodes with local volumes
  cat << EOF | oc apply --validate -f -
apiVersion: local.storage.openshift.io/v1alpha1
kind: LocalVolumeSet
metadata:
  name: ocs-local-block
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: cluster.ocs.openshift.io/openshift-storage
        operator: Exists
  tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
  storageClassName: ocs-local-block
  volumeMode: Block
  deviceInclusionSpec:
    minSize: 100Gi
    deviceTypes: [ ${ODF_DEVICE_TYPES} ]
  ${max_dev_field}
EOF

  if [[ -n "${ODF_ON_CONTROL_PLANE}" ]]; then
    oc patch LocalVolumeSet ocs-local-block --type json -p \
      '[{"op": "add", "path": "/spec/tolerations/1", "value": "{"key":"'${ODF_ON_CONTROL_PLANE}'", "operator":"Exists"}}]'
  fi

else  #specified block disks only

  cat <<EOF | oc apply --validate -f -
apiVersion: local.storage.openshift.io/v1
kind: LocalVolume
metadata:
  name: ocs-local-block
  namespace: openshift-local-storage
spec:
  nodeSelector:
    nodeSelectorTerms:
    - matchExpressions:
      - key: cluster.ocs.openshift.io/openshift-storage
        operator: Exists
  tolerations:
    - key: node.ocs.openshift.io/storage
      operator: Equal
      value: "true"
  storageClassDevices:
    - storageClassName: ocs-local-block
      volumeMode: Block
      devicePaths: [ ${ODF_DEVICE_PATHS} ]
EOF

  if [[ -n "${ODF_ON_CONTROL_PLANE}" ]]; then
    oc patch LocalVolume ocs-local-block --type json -p \
      '[{"op": "add", "path": "/spec/tolerations/1", "value": "{"key":"'${ODF_ON_CONTROL_PLANE}'", "operator":"Exists"}}]'
  fi

fi

echo -n Waiting for local PVs on at least 3 distinct nodes...
while true; do
  pc=$(oc get --no-headers pv -l storage.openshift.com/owner-name=ocs-local-block \
         --ignore-not-found -o custom-columns=':.metadata.labels.kubernetes\.io/hostname' \
         | sort -u | wc -l)
  if [[ $pc -ge 3 ]]; then break; fi
  echo -n .
  sleep 5
done
echo done

echo -n Waiting for any remaining local PVs to be created...
pv_cnt=0
while true; do
  pc=$(oc get --no-headers pv -l storage.openshift.com/owner-name=ocs-local-block \
         --ignore-not-found -o custom-columns=':.metadata.labels.kubernetes\.io/hostname' \
         | wc -l)
  if [[ $pc -eq ${pv_cnt} ]]; then break; fi
  pv_cnt=$pc
  echo -n .
  sleep 30
done
echo done


echo
echo ODF PVs:
oc get pv -l storage.openshift.com/owner-name=ocs-local-block -o wide
echo


cat <<EOF | oc apply --validate -f -
apiVersion: odf.openshift.io/v1alpha1
kind: StorageSystem
metadata:
  name: ocs-storagecluster-storagesystem
  namespace: openshift-storage
spec:
  kind: storagecluster.ocs.openshift.io/v1
  name: ocs-storagecluster
  namespace: openshift-storage
---
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  annotations:
    cluster.ocs.openshift.io/local-devices: "true"
    uninstall.ocs.openshift.io/cleanup-policy: delete
    uninstall.ocs.openshift.io/mode: graceful
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  arbiter: {}
  encryption:
    kms: {}
  externalStorage: {}
  flexibleScaling: true
  managedResources:
    cephBlockPools: {}
    cephCluster: {}
    cephConfig: {}
    cephDashboard: {}
    cephFilesystems: {}
    cephNonResilientPools: {}
    cephObjectStoreUsers: {}
    cephObjectStores: {}
    cephToolbox: {}
  mirroring: {}
  monDataDirHostPath: /var/lib/rook
  nodeTopologies: {}
  multiCloudGateway:
    reconcileStrategy: ignore   #"Disable" MultiCloud/NOOBAA
  storageDeviceSets:
  - config: {}
    count: ${pv_cnt}
    dataPVCTemplate:
      metadata: {}
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: "1"
        storageClassName: ocs-local-block
        volumeMode: Block
    name: ocs-deviceset-localblock
    placement: {}
    preparePlacement: {}
    replica: 1   #ODF replicates to 3 under the covers
    resources: {}
EOF

#TODO:
#    placement:
#      all:
#        nodeAffinity:
#          preferredDuringSchedulingIgnoredDuringExecution:
#          - weight: 100
#            preference:
#              matchExpressions:
#              - key: ${OCP_LOCAL_STORAGE_NODE_LABEL}
#                operator: Exists
#        tolerations:
#        - effect: NoSchedule
#          key: node.ocs.openshift.io/storage
#          value: "true"
#      mds:
#        tolerations:
#        - effect: NoSchedule
#          key: node.ocs.openshift.io/storage
#          value: "true"
#      noobaa-core:
#        tolerations:
#        - effect: NoSchedule
#          key: node.ocs.openshift.io/storage
#          value: "true"
#      rgw:
#        tolerations:
#        - effect: NoSchedule
#          key: node.ocs.openshift.io/storage
#          value: "true"
      
#TODO: patch placement with control-plane toleration

echo -n Waiting for the StorageCluster to be ready and define StorageClasses...
#StorageClasses will show up as the storagecluster progresses through it's status
while true; do
  s=$(oc get storagecluster --ignore-not-found -n openshift-storage ocs-storagecluster -o jsonpath='{.status.phase}')
  if [[ "${s}" == "Ready" ]]; then break; fi
  sleep 5;
  echo -n .
done
echo done

#Make block/RWO the default
oc patch storageclass ocs-storagecluster-ceph-rbd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


#Test storage classes can be provisioned
echo
echo Testing ODF:
cat <<EOF | oc apply --validate -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-cephfs
  namespace: openshift-storage
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10M
  storageClassName: ocs-storagecluster-cephfs
  volumeMode: Filesystem
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-cephrbd
  namespace: openshift-storage
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10M
  storageClassName: ocs-storagecluster-ceph-rbd
  volumeMode: Filesystem
---
apiVersion: objectbucket.io/v1alpha1
kind: ObjectBucketClaim
metadata:
  name: test-cephrgw
  namespace: openshift-storage
spec:
  generateBucketName: test-rgw
  storageClassName: ocs-storagecluster-ceph-rgw
---
apiVersion: v1
kind: Pod
metadata:
  name: test-odf
  namespace: openshift-storage
spec:
  containers:
  - name: test
    command:
    - bash
    args:
    - -c
    - while true; do sleep 60; done
    image: $(oc get po -n openshift-storage -l name=ocs-operator -o jsonpath='{.items[0].spec.containers[0].image}')
    env:
      - name: BUCKET_NAME
        valueFrom:
          configMapKeyRef:
            name: test-cephrgw
            key: BUCKET_NAME
      - name: BUCKET_HOST
        valueFrom:
          configMapKeyRef:
            name: test-cephrgw
            key: BUCKET_HOST
      - name: BUCKET_PORT
        valueFrom:
          configMapKeyRef:
            name: test-cephrgw
            key: BUCKET_PORT
      - name: AWS_ACCESS_KEY_ID
        valueFrom:
          secretKeyRef:
            name: test-cephrgw
            key: AWS_ACCESS_KEY_ID
      - name: AWS_SECRET_ACCESS_KEY
        valueFrom:
          secretKeyRef:
            name: test-cephrgw
            key: AWS_SECRET_ACCESS_KEY
    volumeMounts:
    - mountPath: /var/tmp/cephfs
      name: test-cephfs
    volumeMounts:
    - mountPath: /var/tmp/cephrbd
      name: test-cephrbd
  volumes:
  - name: test-cephfs
    persistentVolumeClaim:
      claimName: test-cephfs
  - name: test-cephrbd
    persistentVolumeClaim:
      claimName: test-cephrbd
EOF

echo -n Waiting for ODF test pod to be ready...
n=0
while [[ $n -lt 180 ]]; do
  s=$(oc get po -n openshift-storage test-odf -o jsonpath='{.status.containerStatuses[0].ready}')
  if [ "${s}" == "true" ]; then break; fi
  sleep 5
  echo -n .
  ((n+=5))
done
echo done

s=$(oc get po -n openshift-storage test-odf -o jsonpath='{.status.containerStatuses[0].ready}')
if [[ "${s}" == "true" ]]; then
  oc delete pod -n openshift-storage test-odf
  oc delete pvc -n openshift-storage test-cephfs
  oc delete pvc -n openshift-storage test-cephrbd
  oc delete obc -n openshift-storage test-cephrgw
  echo 'INFO: ODF StorageClasses appear to be working'
else
  echo 'ERROR: test-odf pod did not become ready!'
  oc describe pod -n openshift-storage test-odf
  oc describe pvc -n openshift-storage test-cephfs
  oc describe pvc -n openshift-storage test-cephrbd
  oc describe obc -n openshift-storage test-cephrgw
  exit $LINENO
fi


echo
echo ODF StorageClasses:
oc get sc
echo

exit 0

