#!/bin/bash

#*===================================================================
#*
# © Copyright IBM Corp. 2020
#*
#*===================================================================


# Function to wait for a specific time, it requires one positional argument i.e timeout
wait() {
   timeout=$1
   i=0
   while [ $i -ne $timeout ]; do
      printf "."
      sleep 1
      ((i++))
   done
}

# Function to check pod readyness using pod label, it requires 3 positional arguments such as namespace, podLabel, retryCount
checkPodReadyness() {
   namespace=$1
   podLabel=$2
   retryCount=$3
   counter=0

   pods=$(oc -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v )

   while [ "${pods}" ]; do
      wait "5"
      echo "Waiting for Pods to be READY"

      pods=$(oc -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v )

      ((counter++))
      if [[ $counter -eq $retryCount ]]; then
         echo "Pods in $namespace namespace are not READY hence terminating the process"
         exit 1
      fi
   done
}

# Function to check resource readyness, it requires 4 positional arguments such as namespace, jobLabel, retryCount and resourceType
checkResourceReadyness() {
   namespace=$1
   resourceLabel=$2
   retryCount=$3
   resourceType=$4
   counter=0
   resources=$(oc -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
   echo Resources: $resources

   while [ "${resources}" ]; do
      wait "5"
      echo "Waiting for resource to be READY"

      resources=$(oc -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
      echo Resources: $resources

      counter=$((counter+1))
      echo Counter: $counter, RetryCount: $retryCount

      if [ $counter -eq $retryCount ]; then
         echo "$resources are not ready"
         break
      fi
   done
}
