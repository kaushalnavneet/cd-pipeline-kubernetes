#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
CHART_NAMESPACE=${CHART_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}
WORKDIR=${WORKDIR:-/work}
ACCOUNT_ID=${DEPLOY_ACCOUNT_ID:-${ACCOUNT_ID}}
API_KEY=${DEPLOY_API_KEY:-${API_KEY}}

printf "Deploying release ${IDS_STAGE_NAME} into cluster ${IDS_JOB_NAME},\nnamespace ${CHART_NAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}.\n"

cp -a ${WORKDIR} cd-pipeline-kubernetes
bx login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(bx cs cluster-config --export ${IDS_JOB_NAME})

INGRESS_SUBDOMAIN=$(bx cs cluster-get -s ${IDS_JOB_NAME} | grep -i "Ingress subdomain:" | awk '{print $3;}')
INGRESS_SECRET=$(bx cs cluster-get -s {IDS_JOB_NAME} | grep -i "Ingress secret:" | awk '{print $3;}')

tmp=$(mktemp)
yq --yaml-output --arg stagename "${IDS_STAGE_NAME}" '. | .pipeline.fullnameOverride=$stagename | .pipeline.nameOverride=$stagename' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

helm dep up ${COMPONENT_NAME}
if ! helm list ${IDS_STAGE_NAME}; then
  deleted=$(helm list --all ${IDS_STAGE_NAME} | grep DELETED)
  if [ -z $deleted ]; then
    helm delete --purge ${IDS_STAGE_NAME}
  fi
  helm install --name ${IDS_STAGE_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_NAME} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
else
  helm upgrade ${IDS_STAGE_NAME} ${COMPONENT_NAME} --install --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_NAME} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
fi
