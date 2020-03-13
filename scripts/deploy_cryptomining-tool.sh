#!/bin/bash
CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
ENVIRONMENT=${ENVIRONMENT:-dev}
DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/cryptomining_values.yaml

helm upgrade cryptomining-detector helm/cryptomining-detector \
  --install \
  --namespace "${CHART_NAMESPACE}" \
  --values=${VALUES}
  --timeout 600 \
  --debug
