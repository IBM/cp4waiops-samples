#!/bin/bash

KAFKA_POD=$1
BROKER=$2
KAFKATOPIC=$3

kubectl exec -it $KAFKA_POD -- bash -c "/opt/kafka/bin/kafka-console-producer.sh --broker-list $BROKER --topic $KAFKATOPIC < /tmp/shipping_event.json"

