
strimzi_kafka_image="strimzi/kafka"
strimzi_operator_image="strimzi/operator"
strimzi_kafka_bridge_image="strimzi/kafka-bridge"
strimzi_kafka_jmxtrans_image="strimzi/jmxtrans"

images_url=("$strimzi_kafka_image:0.19.0-kafka-2.4.0"
            "$strimzi_kafka_image:0.19.0-kafka-2.4.1"
            "$strimzi_kafka_image:0.19.0-kafka-2.5.0"
            "$strimzi_operator_image:0.19.0"
            "$strimzi_kafka_bridge_image:0.18.0"
            "$strimzi_kafka_jmxtrans_image:0.19.0")

#This is the original registry for strimzi images
original_registry="docker.io"

strimzi_release_artifact="https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.19.0/strimzi-0.19.0.tar.gz"

#Namespace where strimzi operator will be installed.
strimzi_operator_namespace="openshift-operators"

# This is your mirror registry where you want to mirror the strimzi images
#export LOCAL_DOCKER_REGISTRY=

#Provide the creds for your mirror registry
#export LOCAL_DOCKER_REGISTRY_USER=
#export LOCAL_DOCKER_REGISTRY_PASSWORD=


echo "[INFO] Checking Pre-requisites['podman','skopeo','wget']:"
if podman -v 2> /dev/null ;then
   echo "[INFO] Pre-requisite 'Podman' exists"
else
   echo "[ERROR] Pre-requisite 'podman' does not exists, please install and try again"
   exit 1
fi

if skopeo -v 2> /dev/null ;then
   echo "[INFO] Pre-requisite 'skopeo' exists"
else
   echo "[ERROR] Pre-requisite 'skopeo' does not exists, please install and try again"
   exit 1
fi

if wget -V 2> /dev/null ;then
   echo "[INFO] Pre-requisite 'wget' exists"
else
   echo "[ERROR] Pre-requisite 'wget' does not exists, please install and try again"
   exit 1
fi

echo "[INFO] Pre-requisites exists, running the script"

echo "[INFO] Vefifying if all the registry environment variables details are provided correctly."
if [[ ( ! -z "$LOCAL_DOCKER_REGISTRY" ) && ( ! -z "$LOCAL_DOCKER_REGISTRY_USER" ) && ( ! -z "$LOCAL_DOCKER_REGISTRY_PASSWORD" ) ]]; then
   echo "Trying to login to local docker registry registry $LOCAL_DOCKER_REGISTRY"
   podman login -u $LOCAL_DOCKER_REGISTRY_USER -p $LOCAL_DOCKER_REGISTRY_PASSWORD $LOCAL_DOCKER_REGISTRY --tls-verify=false
   if [ $? -gt 0 ]; then
      echo "[ERROR] Some error occured while login to the mirror registry $LOCAL_DOCKER_REGISTRY"
      exit 1
   fi  
else
   echo "[ERROR] Some or all of the environment variables are not set correctly. Please set the environment variables and try again."
   echo "[INFO] LOCAL_DOCKER_REGISTRY='$LOCAL_DOCKER_REGISTRY'"
   echo "[INFO] LOCAL_DOCKER_REGISTRY_USER='$LOCAL_DOCKER_REGISTRY_USER'"
   echo "[INFO] LOCAL_DOCKER_REGISTRY_PASSWORD='$LOCAL_DOCKER_REGISTRY_PASSWORD'"
   exit 1
fi


for image in ${images_url[@]}; do
    echo "[INFO] Mirroring the image: '$image' to mirror registry as '$LOCAL_DOCKER_REGISTRY/$image'"    
    skopeo copy --all docker://$original_registry/$image docker://$LOCAL_DOCKER_REGISTRY/$image --tls-verify=false
done

if [ $? -gt 0 ]; then
   echo "[ERROR] Some error occured in pulling or pushing the images. Please check the logs, and try to debug why the images were not pushed to your mirror registry"
   exit 1
fi


if [ -f "strimzi-0.19.0.tar.gz" ]; then
   rm -rf strimzi-0.19.0.tar.gz
fi
#Downloading Strimzi release artifacts version 0.19.0
wget $strimzi_release_artifact
if [ $? -gt 0 ]; then
   echo "[ERROR] Some error while downloading the strimzi binary file strimzi-0.19.0.tar.gz"
   exit 1
fi

if test -f "strimzi-0.19.0.tar.gz"; then 
    echo "[INFO] strimzi-0.19.0.tar.gz file exists."
    echo "[INFO] Removing old directory if present strimzi-0.19.0"
    if [ -d "strimzi-0.19.0" ]; then
       rm -rf strimzi-0.19.0
    fi
    tar -xvf strimzi-0.19.0.tar.gz
else 
    echo "[ERROR] File strimzi-0.19.0.tar.gz does not exists"
    exit 1
fi

echo "[INFO] Checking if the directory strimzi-0.19.0 exists"

if [ -d "strimzi-0.19.0" ]; then 
   echo "[INFO] Directory strimzi-0.19.0 exists"
   cd strimzi-0.19.0
   echo "[INFO] Current path: "
   pwd
else
   echo "[ERROR] The directory 'strimzi-0.19.0' does not exists, some issue while unzipping the tar file strimzi-0.19.0.tar.gz"
   exit 1
fi


sed -i 's/namespace: .*/namespace: '"$strimzi_operator_namespace"'/' install/cluster-operator/*RoleBinding*.yaml
sed -i '/fieldPath: metadata.namespace/d' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml
sed -i '/fieldRef:/d' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml
sed -i 's/valueFrom:/value: "*"/' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml

echo "Updating the image url registry url in the deployment.yaml"
sed -i 's|'"$strimzi_kafka_bridge_image"':|'"$LOCAL_DOCKER_REGISTRY"'/'"$strimzi_kafka_bridge_image"':|g' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml
sed -i 's|'"$strimzi_kafka_image"':|'"$LOCAL_DOCKER_REGISTRY"'/'"$strimzi_kafka_image"':|g' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml
sed -i 's|'"$strimzi_operator_image"':|'"$LOCAL_DOCKER_REGISTRY"'/'"$strimzi_operator_image"':|g' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml
sed -i 's|'"$strimzi_kafka_jmxtrans_image"':|'"$LOCAL_DOCKER_REGISTRY"'/'"$strimzi_kafka_jmxtrans_image"':|g' install/cluster-operator/050-Deployment-strimzi-cluster-operator.yaml

#Create ClusterRoleBindings
oc create clusterrolebinding strimzi-cluster-operator-namespaced --clusterrole=strimzi-cluster-operator-namespaced --serviceaccount $strimzi_operator_namespace:strimzi-cluster-operator
oc create clusterrolebinding strimzi-cluster-operator-entity-operator-delegation --clusterrole=strimzi-entity-operator --serviceaccount $strimzi_operator_namespace:strimzi-cluster-operator
oc create clusterrolebinding strimzi-cluster-operator-topic-operator-delegation --clusterrole=strimzi-topic-operator --serviceaccount $strimzi_operator_namespace:strimzi-cluster-operator

#Deploy the Cluster Operator t
oc apply -f install/cluster-operator -n $strimzi_operator_namespace
if [ $? -gt 0 ]; then
   echo "[ERROR] Some issue occured while running oc apply command, please check if you are logged in your openshift cluster"
   exit 1
else
   echo "[INFO] Strimzi operator was installed. Please verify with below command."
   echo "[INFO] Run command to check if the pod is running for strimzi operator 'oc get pods -n $strimzi_operator_namespace'"
fi
