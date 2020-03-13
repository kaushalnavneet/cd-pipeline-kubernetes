#!/bin/bash
CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
ENVIRONMENT=${ENVIRONMENT:-dev}

helm upgrade cryptomining-detector helm/cryptomining-detector \
  --install \
  --namespace "${CHART_NAMESPACE}" \
  --values=environments/"${ENVIRONMENT}"/cryptomining_values.yaml \
  --timeout 600 \
  --debug
