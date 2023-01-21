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
    mkdir -p /bcdr/backup

ADD backup/scripts /bcdr/backup/scripts
ADD common /bcdr/common
WORKDIR /bcdr/backup/scripts

CMD ["/bin/bash", "main.sh"]
