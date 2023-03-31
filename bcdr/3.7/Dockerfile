FROM redhat/ubi8-minimal:latest

#Install the Velero and OpenShift client tool alongwith curl, jq and wget
RUN microdnf update -y && microdnf install -y curl tar gzip jq  && \
    curl -LO https://github.com/vmware-tanzu/velero/releases/download/v1.9.0/velero-v1.9.0-linux-amd64.tar.gz && \
    tar -xzf velero-v1.9.0-linux-amd64.tar.gz && \
    mv velero-v1.9.0-linux-amd64/velero /usr/local/bin/velero && \
    rm -rf velero-v1.9.0-linux-amd64* && \
    curl -LO https://github.com/openshift/okd/releases/download/4.10.0-0.okd-2022-03-07-131213/openshift-client-linux-4.10.0-0.okd-2022-03-07-131213.tar.gz && \
    tar xvf openshift-client-linux-4.10.0-0.okd-2022-03-07-131213.tar.gz && \
     mv oc /usr/local/bin && \
    rm -rf openshift-client-linux-4.10.0-0.okd-2022-03-07-131213* && \
    rm -f kubectl && \
    mkdir -p /bcdr/backup && \
    mkdir -p /bcdr/restore && \
    mkdir -p /bcdr/common

ADD backup/scripts /bcdr/backup/scripts
ADD common /bcdr/common
ADD restore/cam /bcdr/restore/cam
ADD restore/cassandra /bcdr/restore/cassandra
ADD restore/common-services /bcdr/restore/common-services
ADD restore/couchdb /bcdr/restore/couchdb
ADD restore/elasticsearch /bcdr/restore/elasticsearch
ADD restore/infrastructure-management /bcdr/restore/infrastructure-management
ADD restore/metastore /bcdr/restore/metastore
ADD restore/minio /bcdr/restore/minio
ADD restore/other-resources /bcdr/restore/other-resources
ADD restore/postgres /bcdr/restore/postgres
ADD restore/vault /bcdr/restore/vault
ADD restore/restore-data.json /bcdr/restore/restore-data.json
ADD restore/restore-utils.sh /bcdr/restore/restore-utils.sh
ADD restore/restore.sh /bcdr/restore/restore.sh

