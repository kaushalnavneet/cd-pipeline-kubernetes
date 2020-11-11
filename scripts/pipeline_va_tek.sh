#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-cloud.ibm.com}
IMAGE_URL=${IMAGE_URL:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}
DOCKERFILE=${DOCKERFILE:-docker/Dockerfile.${DOCKER_IMAGE##*:}}

ibmcloud login -a ${IBM_CLOUD_API} -r ${ACCOUNT_REGION} --apikey ${DOCKER_PASSWORD}

# default value for PIPELINE_IMAGE_URL -- uncomment and customize as needed
export PIPELINE_IMAGE_URL="${IMAGE_URL}:${APPLICATION_VERSION}"
echo "PIPELINE_IMAGE_URL=${PIPELINE_IMAGE_URL}"

for iteration in {1..30}
do
  BX_CR_VA=$(ibmcloud cr va $PIPELINE_IMAGE_URL --output json)
  if [[ $? -eq 0 ]]; then
    BX_CR_VA=$(echo -n ${BX_CR_VA} | jq -r '.[] .status')
    echo "BX_CR_VA=${BX_CR_VA}"
    if [[ "${BX_CR_VA}" == "OK" ]]; then
      break
    fi
  else
    echo "error while running va check: ${BX_CR_VA}"
  fi
  echo -e "A vulnerability report was not found for the specified image, either the image doesn't exist or the scan hasn't completed yet. Waiting for scan to complete.."
  sleep 10
done
echo "${BX_CR_VA}"
if [[ ! "${BX_CR_VA}" == "OK" ]]; then
  echo "ERROR: The vulnerability scan was not successful, check the output of the command and try again."
  exit 1
fi
