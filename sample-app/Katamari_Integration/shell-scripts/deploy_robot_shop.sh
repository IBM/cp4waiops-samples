#!/bin/bash

# This script will:
# 
# 1) clone the Instana Robot-Shop repo
# 2) Update necessary files
# 3) Deploy the robot-shop
# 4) Perform necessary post install deployments/configuration(TBD)
#
# NOTE: this script is specific to IKS, for Openshift there are some
# minor changes that must be made.

RS_URL="https://github.com/instana/robot-shop.git"
HELM3="/usr/local/bin/helm3"
WHERE=$(pwd)
WORKDIR="/usr/local/automation_work"

if [ -z "${1}" -o -z "${2}" ]
then
    echo "Usage:"
    echo "$0 <namespace to create robot-shop> <robotshop cluster_id>"
    exit 1
fi

cd $WORKDIR

NAMESPACE="robotshop-${1}"
RS_CLUSTER_ID="${2}"

# Confirm we are logged into correct CLUSTER
#if [ -z "$(kubectl config current-context | grep ${RS_CLUSTER_ID})" ]
#then
#    echo -e "This is not the robotshop cluster. Please make sure you are logged into the correct cluster and try again."
#    exit 255
#fi

# Ensure namespace does not already exist
kubectl get namespace ${NAMESPACE} 2> /dev/null

if [ $? -eq 0 ]
then
   echo -e "The namespace ${NAMESPACE} already exists in the environment, please clean it up and try again, or use a different namespace."
   exit 255
fi

# Create namespace
echo -e "Creating namespace: ${NAMESPACE}"
kubectl create namespace ${NAMESPACE}

if [ $? -ne 0 ]
then
    echo -e "FATAL error creating namespace: ${NAMESPACE}"
    exit 255
fi

# Make namespace directory and move to it
if [ ! -d ${WORKDIR}/${NAMESPACE}-data ]
then
	mkdir ${WORKDIR}/${NAMESPACE}-data 
fi
	
cd ${WORKDIR}/${NAMESPACE}-data

if [ $? -ne 0 ]
then
    echo -e "Unable to create and cd to directory(${NAMESPACE})"
    echo -e "Please ensure you have write access to the current directory and try again."
    exit 255
fi

# Clone robot-shop repo
echo -e "Cloning robot-shop repo"
git clone ${RS_URL} 

if [ $? -ne 0 ]
then
    echo -e "Unable to clone $RS_URL."
    echo -e "Please ensure git is installed and you can clone the repo manually."
    exit 255
fi

cd robot-shop/K8s/helm/

# Update redis storage class
sed -i "s/standard/default/" values.yaml

# Install helm3 chart
echo -e "Deploying robot-shop to ${NAMESPACE}"
${HELM3} install robot-shop -n ${NAMESPACE} --set image.version=2.0.1 --set redis.storageClassName=default .

if [ $? -ne 0 ]
then
    echo -e "Unable to install templates via helm: $?"
    exit 255
fi

echo -e "Waiting for application to deploy and come to a fully running state."
echo -e "Please be patient, this can take up to 10 minutes."
TIMEOUT=0

while [ ${TIMEOUT} -le 250 ]
do
    # Note, grepping for 1/1 here instead of Running as it does not mean that the
    # pod is ready, we want to ensure all pods are Running AND Ready
    COUNT=$(kubectl get po --no-headers=true -n ${NAMESPACE} | grep -v "1\/1" | wc -l)
    if [ ${COUNT} -eq 0 ]
    then
        echo ""
        echo -e "All pods are in a running/ready state, deployment has completed successfully."
        cd ${WHERE}
        exit 0
    fi
    sleep 3
    ((TIMEOUT+=1))
    echo -n .
done

cd ${WHERE}

if [ ${TIMEOUT} -ge 250 ]
then
    echo -e "Deployment did not complete in the time alloted, please manually check the deployment."
    exit 255
fi

