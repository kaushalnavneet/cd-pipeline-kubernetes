#!/bin/bash

cp -a /work cd-pipeline-kubernetes

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}

bx login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(bx cs cluster-config --export ${BUILD_CLUSTER})

kubectl --namespace otc-dev get pods 
kubectl --namespace otc-dev port-forward $(kubectl --namespace otc-dev get pods | grep docker | awk '{print $1;}') 2375:2375 > /dev/null 2>&1 &

while ! nc -z localhost 2375; do   
  sleep 0.1
done

export DOCKER_HOST='tcp://localhost:2375'

echo ${APPLICATION_VERSION} > .pipeline_build_id
echo "{\"id\":\"$GIT_COMMIT-$(date +%Y%m%d%H%M%Z)\"}" > build_info.json

docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ${IMAGE_NAME%%/*}
# For some reason this doesn't get repulled in docker engine
docker pull ${DOCKER_IMAGE}
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker pull command\"
    exit 1
fi

docker build . -t ${IMAGE_NAME}:${APPLICATION_VERSION} -f ${DOCKERFILE} --build-arg COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false

if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker build command\"
    exit 1
fi

docker tag ${IMAGE_NAME}:${APPLICATION_VERSION} ${IMAGE_NAME}:latest
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker tag command\"
    exit 1
fi

docker push ${IMAGE_NAME}:${APPLICATION_VERSION}
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker push command\"
    exit 1
fi

docker push ${IMAGE_NAME}:latest
