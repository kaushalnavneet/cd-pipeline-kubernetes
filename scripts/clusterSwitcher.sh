#!/bin/bash

NAMESPACE=${3:-opentoolchain}

export KUBECONFIG=~/.bluemix/plugins/container-service/clusters/"$1"/kube-config
-"$2"-"$1".yml

eval $CONFIG

kubectl config set-context $(kubectl config current-context) --namespace ${NAMESPACE} > /dev/null
echo "export KUBECONFIG=""$KUBECONFIG"
