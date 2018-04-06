#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
COMPONENT_NAME=${COMPONENT_NAME:-$(s=${OUTPUT_IMAGE%%:*} && echo ${s##*/})}
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

docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${OUTPUT_IMAGE%%/*}
docker build . -t ${OUTPUT_IMAGE}:${APPLICATION_VERSION} -f ${DOCKERFILE} --build-arg COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false
docker tag ${OUTPUT_IMAGE}:${APPLICATION_VERSION} ${OUTPUT_IMAGE}:latest
docker push ${OUTPUT_IMAGE}:${APPLICATION_VERSION}
docker push ${OUTPUT_IMAGE}:latest
