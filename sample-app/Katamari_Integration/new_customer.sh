#!/bin/bash

if [ -z "${1}" ]
then
	echo "Usage: $0 <customerName>"
	exit 255
fi

ansible-playbook deploy-katamari-customer-stack.yml --extra-vars="CUSTOMER=${1}"
