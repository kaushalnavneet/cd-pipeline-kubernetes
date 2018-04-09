#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME%%:*}}
CHART_NAMESPACE=${CHART_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}

cp -a /work cd-pipeline-kubernetes
bx login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(bx cs cluster-config --export ${IDS_JOB_NAME})

helm dep up ${IDS_STAGE_NAME}
if ! helm list ${IDS_STAGE_NAME}; then
  deleted=$(helm list --all $IDS_STAGE_NAME} | grep DELETED)
  if [ -z $deleted ]; then
    helm delete --purge ${IDS_STAGE_NAME}
  fi
  helm install --name ${IDS_STAGE_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${COMPONENT_NAME}
  else
    helm upgrade ${IDS_STAGE_NAME} ${CHART_DIR} --install --namespace ${CHART_NAMESPACE} --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_NAME}
  fi
fi
