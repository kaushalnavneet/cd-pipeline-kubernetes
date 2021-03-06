#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2021. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
set -eo pipefail
CHART_NAMESPACE=${CHART_NAMESPACE:-tekton-pipelines}
SCHEDULE=${SCHEDULE:-120}

if [ -n ${IDS_TOKEN} ]; then
  echo "IDS_TOKEN set"
  set +e
  kubectl -n${CHART_NAMESPACE} delete secret cryptomining-secret
  set -e
  kubectl -n${CHART_NAMESPACE} create secret generic cryptomining-secret --from-literal=IDS_TOKEN=${IDS_TOKEN}
else
  echo "IDS_TOKEN is not set"
  exit 1
fi

if [ -n ${DOCKER_CONFIG_JSON} ]; then
  echo "DOCKER_CONFIG_JSON is set"
  set +e
  kubectl -n${CHART_NAMESPACE} delete secret cryptomining-detector-registry-secret
  DOCKER_CONFIG=$(echo -n ${DOCKER_CONFIG_JSON} | base64 -d)
  set -e
  kubectl -n${CHART_NAMESPACE} create secret generic cryptomining-detector-registry-secret \
      --from-literal=.dockerconfigjson=${DOCKER_CONFIG} \
      --type=kubernetes.io/dockerconfigjson
else
  echo "DOCKER_CONFIG_JSON is not set"
  exit 1
fi

JQ_VERSION='1.6'
wget --quiet --no-check-certificate https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64 -O /tmp/jq-linux64 \
    && cp /tmp/jq-linux64 /usr/bin/jq \
    && chmod +x /usr/bin/jq \
    && rm -f /tmp/jq-linux64

# do substitution inside json files located in releng folder
if [ -f releng/final_crypto_deploy.json ]; then
  echo "substitution is alredy done for crypto_deploy.json"
else
  cat releng/crypto_deploy.json | jq --arg CLUSTER_NAME ${CLUSTER_NAME} '(.spec.template.spec.containers[].env[] | select(.name == "CLUSTER_NAME") | .value) = $CLUSTER_NAME' > releng/1.json
  cat releng/1.json | jq --arg IMAGE_NAME ${IMAGE_NAME} '(.spec.template.spec.containers[].image) = $IMAGE_NAME' > releng/2.json
  cat releng/2.json | jq --arg SCHEDULE ${SCHEDULE} '(.spec.template.spec.containers[].env[] | select(.name == "SCHEDULE") | .value) = $SCHEDULE' > releng/3.json
  cat releng/3.json | jq --arg CHART_NAMESPACE ${CHART_NAMESPACE} '(.metadata.namespace) = $CHART_NAMESPACE' > releng/final_crypto_deploy.json
  rm releng/crypto_deploy.json 
  rm releng/1.json
  rm releng/2.json
  rm releng/3.json
fi

if [ -f releng/final_crypto_serviceaccount.json ]; then
  echo "substitution is alredy done for crypto_serviceaccount.json"
else
  cat releng/crypto_serviceaccount.json | jq --arg CHART_NAMESPACE ${CHART_NAMESPACE} '(.metadata.namespace) = $CHART_NAMESPACE' > releng/final_crypto_serviceaccount.json
  rm releng/crypto_serviceaccount.json
fi

if [ -f releng/final_crypto_rolebinding.json ]; then
  echo "substitution is alredy done for crypto_rolebinding.json"
else
  cat releng/crypto_rolebinding.json | jq --arg CHART_NAMESPACE ${CHART_NAMESPACE} '(.subjects[].namespace) = $CHART_NAMESPACE' > releng/final_crypto_rolebinding.json
  rm releng/crypto_rolebinding.json
fi
set +e
kubectl delete clusterrole cryptomining-detector-role
set -eo pipefail
kubectl apply -f releng/