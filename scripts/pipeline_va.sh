#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}

bx login -a ${IBM_CLOUD_API} --apikey ${DOCKER_PASSWORD}
# default value for PIPELINE_IMAGE_URL -- uncomment and customize as needed
export PIPELINE_IMAGE_URL="${IMAGE_NAME}:${APPLICATION_VERSION}"
echo "PIPELINE_IMAGE_URL=${PIPELINE_IMAGE_URL}"

for iteration in {1..30}
do
  BX_CR_VA=$(bx cr va $PIPELINE_IMAGE_URL) 
  if [[ "${BX_CR_VA}" =~ SAFE ]] || [[ "${BX_CR_VA}" =~ CAUTION ]] || [[ "${BX_CR_VA}" =~ BLOCKED ]]; then
    break
  fi

  echo -e "A vulnerability report was not found for the specified image, either the image doesn't exist or the scan hasn't completed yet. Waiting for scan to complete.."
  sleep 10
done

echo "${BX_CR_VA}"
[[ ${BX_CR_VA} == *SAFE* ]] || { echo "ERROR: The vulnerability scan was not successful, check the output of the command and try again."; exit 1; }
