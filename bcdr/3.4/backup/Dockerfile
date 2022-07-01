FROM alpine:latest

RUN apk --no-cache add curl jq wget && \
    curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    wget -O velero-v1.6.0-linux-amd64.tar.gz https://github.com/vmware-tanzu/velero/releases/download/v1.6.0/velero-v1.6.0-linux-amd64.tar.gz && \
    tar -xvf velero-v1.6.0-linux-amd64.tar.gz && \
    mv velero-v1.6.0-linux-amd64/velero /usr/local/bin/velero

WORKDIR /scripts

ADD /scripts .

CMD ["sh", "main.sh"]
