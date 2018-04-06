#!/bin/bash

cp -a /work cd-pipeline-kubernetes

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME%%:*}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}

bx login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(bx cs cluster-config --export ${BUILD_CLUSTER})

kubectl --namespace otc-dev get pods 
kubectl --namespace otc-dev port-forward $(kubectl --namespace otc-dev get pods | grep docker | awk '{print $1;}') 2375:2375 > /dev/null 2>&1 &

while ! nc -z localhost 2375; do   
  sleep 0.1
done

export DOCKER_HOST='tcp://localhost:2375'

APPLICATION_VERSION="$GIT_COMMIT-$(date +%Y%m%d%H%M%Z)"
echo ${APPLICATION_VERSION} > .pipeline_build_id
echo "{\"id\":\"$GIT_COMMIT-$(date +%Y%m%d%H%M%Z)\"}" > build_info.json

docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${IMAGE_NAME%%/*}A
# For some reason this doesn't get repulled in docker engine
docker pull -f ${DOCKER_IMAGE}
docker build . -t ${IMAGE_NAME}:${APPLICATION_VERSION} -f ${DOCKERFILE} --build-arg COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false
docker tag ${IMAGE_NAME}:${APPLICATION_VERSION} ${IMAGE_NAME}:latest
docker push ${IMAGE_NAME}:${APPLICATION_VERSION}
docker push ${IMAGE_NAME}:latest
