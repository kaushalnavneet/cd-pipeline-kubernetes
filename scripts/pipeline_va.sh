#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}

bx login -a ${IBM_CLOUD_API} --apikey ${DOCKER_PASSWORD}
# default value for PIPELINE_IMAGE_URL -- uncomment and customize as needed
export PIPELINE_IMAGE_URL="${IMAGE_NAME}:${APPLICATION_VERSION}"
echo "PIPELINE_IMAGE_URL=${PIPELINE_IMAGE_URL}"

for iteration in {1..3}
do
  [[ $(bx cr va $PIPELINE_IMAGE_URL) == *BXNVA0009E* ]] || break
  echo -e "A vulnerability report was not found for the specified image, either the image doesn't exist or the scan hasn't completed yet. Waiting for scan to complete.."
  sleep 60
done

set +e
bx cr va $PIPELINE_IMAGE_URL
set -e
[[ $(bx cr va $PIPELINE_IMAGE_URL) == *SAFE\ to\ deploy* ]] || { echo "ERROR: The vulnerability scan was not successful, check the output of the command and try again."; exit 1; }
