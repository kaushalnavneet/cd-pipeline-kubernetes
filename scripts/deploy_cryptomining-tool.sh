#!/bin/bash

CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
ENVIRONMENT=${ENVIRONMENT:-dev}
DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/cryptomining_values.yaml

helm ls | grep cryptomining-detector
if [[ $? == 0 ]]; then
  helm delete --purge cryptomining-detector
  result=$(echo $?)
  if [[ result == 1 ]]; then
    echo "Could not purge existing chart"
    exit 1
  else
    echo "Purged existing chart"
    sleep 60
  fi
else
  echo "char for cryptomining detector doesn't exist"
fi

kubectl get deployments -n "${NAMESPACE}" | grep cryptomining-detector
result=$(echo $?)
if [[ result == 0 ]]; then
  echo "Remove cryptomining deployment"
  kubectl -n "${NAMESPACE}" delete deployment cryptomining-detector
  sleep 60
fi

helm upgrade cryptomining-detector helm/cryptomining-detector \
  --install \
  --namespace "${CHART_NAMESPACE}" \
  --values=${VALUES} \
  --debug
