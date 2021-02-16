#!/bin/bash

if [[ $# -ne 1 ]]; then
  echo "usage: subpipe.sh [main local pipeline file]"
  exit 1
fi

main=$1

      
echo "==============================="
echo "Setting up sidecar ..."
kubectl create -f k8s/sidecar-deployment.yaml

while [[ $(kubectl get pods -l app=tekton-localpipeline-sidecar -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 5; done
SIDECAR=$(kubectl get pods --selector app=tekton-localpipeline-sidecar -o=custom-columns=NAME:.metadata.name --no-headers)

echo "Copying over files ..."
kubectl cp . $SIDECAR:data/

echo "Starting main pipeine ..." 
kubectl create -f $main

echo "==============================="