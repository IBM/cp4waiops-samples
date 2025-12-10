#!/bin/bash

#*===================================================================
#*
#   © Copyright IBM Corp. 2021, 2023
#   
#   
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

   pods=$(kubectl -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v )

   while [ "${pods}" ]; do
      wait "5"
      echo "[INFO] $(date) Waiting for Pods to be READY"

      pods=$(kubectl -n $namespace get pods -l $podLabel --no-headers | grep -F "1/1" -v )

      ((counter++))
      if [[ $counter -eq $retryCount ]]; then
         echo "[ERROR] $(date) Pods in $namespace namespace are not READY hence terminating the process"
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
   resources=$(kubectl -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
   echo "[INFO] $(date) Resources: $resources"

   while [ "${resources}" ]; do
      wait "5"
      echo "[INFO] $(date) Waiting for resource to be READY"

      resources=$(kubectl -n $namespace get $resourceType -l $resourceLabel --no-headers | grep -F "1/1" -v)
      echo "[INFO] $(date) Resources: $resources"

      counter=$((counter+1))
      echo "[INFO] $(date) Counter: $counter, RetryCount: $retryCount"

      if [ $counter -eq $retryCount ]; then
         echo "[WARNING] $(date) $resources are not ready"
         break
      fi
   done
}

# Function to check pod readyness using pod label, it requires 3 positional arguments such as namespace, podLabel, retryCount
checkPodReadynessV2() {
   namespace=$1
   podLabel=$2
   retryCount=$3
   #counter=0
   podReadynessCheckValue=0

   podList=$(kubectl -n $namespace get pods -l $podLabel --no-headers=true --output=custom-columns=NAME:.metadata.name )
   echo -e "[INFO] $(date) pods having label $podLabel are \n$podList"

   if [ -z "$podList" ]; then
        echo "[ERROR] $(date) No pod found with label $podLabel, hence exiting"
        #exit 1
        podReadynessCheckValue=1
        return $podReadynessCheckValue
   fi

   for pod in $podList; do
       counter=0
       echo "[Debug] $(date) Counter value is $counter"
       wait "10"
       while [ $counter -ne $retryCount ]; do
          status1=$(kubectl get pod $pod -n $namespace -o=jsonpath='{.status.phase}')
          status2=$(kubectl get pod $pod -n $namespace -o=jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
          echo "[INFO] $(date) Pod $pod running status is $status1 and ready status is $status2"
          if [[  $status1 != "Running"  ]] || [[ $status2 != "True" ]]; then
                echo "[INFO] $(date) Pod $pod is not in running/ready state, waiting for the pod to be READY"
                wait "10"
                ((counter++))
                if [[ $counter -eq $retryCount ]]; then
                   echo "[ERROR] $(date) Exiting as pod $pod is still not in running/ready state after waiting maximum time"
                   #exit 1
                   podReadynessCheckValue=1
                   return $podReadynessCheckValue
                fi
          else 
                echo "[INFO] $(date) Pod $pod is in $status1 and Ready state"
                break
          fi
       done
   done

}





checkResourceReadynessV2() {
   namespace=$1
   resourceName=$2
   retryCount=$3
   resourceType=$4
   counter=0
   resource=$(kubectl -n $namespace get $resourceType $resourceName --no-headers | cut -d " " -f 1)
   echo "[INFO] $(date) Resources: $resources"

   while [ -z "${resources}" ]; do
      wait "5"
      echo "[INFO] $(date) Waiting for resource to be present"

      resources=$(kubectl -n $namespace get $resourceType $resourceName --no-headers | cut -d " " -f 1)
      echo "[INFO] $(date) Resource: $resources"

      counter=$((counter+1))
      echo "[INFO] $(date) Counter: $counter, RetryCount: $retryCount"

      if [ $counter -eq $retryCount ]; then
         echo "[WARNING] $(date) $resource is not present"
         break
      fi
   done
}

