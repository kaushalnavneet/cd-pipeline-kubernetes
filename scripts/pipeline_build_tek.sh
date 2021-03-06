#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017, 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
cp -a /work cd-pipeline-kubernetes

IBM_CLOUD_API=${IBM_CLOUD_API:-cloud.ibm.com}
IMAGE_URL=${IMAGE_URL:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}

ibmcloud login -a ${IBM_CLOUD_API} --apikey ${API_KEY} -r ${ACCOUNT_REGION}

ksversion=$(ibmcloud plugin list | grep kubernetes | awk '{print $2}' | head -c1)
if [ "$ksversion" -eq "0"  ]; then
    $(ibmcloud ks cluster config --export --cluster ${BUILD_CLUSTER})
else
    ibmcloud ks cluster config --cluster ${BUILD_CLUSTER}
fi

kubectl --namespace otc-dev get pods 
kubectl --namespace otc-dev port-forward $(kubectl --namespace otc-dev get pods | grep docker | grep Running | awk '{print $1;}') 2375:2375 > /dev/null 2>&1 &

while ! nc -z localhost 2375; do   
  sleep 0.1
done

export DOCKER_HOST='tcp://localhost:2375'


if [ -z "$GIT_COMMIT" ]; then
  GIT_COMMIT=$(git rev-parse --verify HEAD)
fi
TIMESTAMP=$(date +%Y%m%d%H%M%Z)
if [ -z "$APPLICATION_VERSION" ]; then
  APPLICATION_VERSION="${GIT_COMMIT}-${TIMESTAMP}"
fi

 echo ${APPLICATION_VERSION} > /artifacts/appVersion

echo "Building ${IMAGE_URL}:${APPLICATION_VERSION}"
echo ${APPLICATION_VERSION} > .pipeline_build_id
echo "{\"build\": \"$TIMESTAMP\",\"commit\":\"$GIT_COMMIT\",\"appName\" : \"${COMPONENT_NAME}\",\"platform\" : \"Armada\"}" > build_info.json

docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ${IMAGE_URL%%/*}
# For some reason this doesn't get repulled in docker engine
docker pull ${DOCKER_IMAGE}
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker pull command\"
    exit 1
fi
echo "Dockerfile: ${DOCKERFILE}"
if [ "$OPERATOR_SDK" == true ]; then
go mod vendor
operator-sdk build ${IMAGE_URL}:${APPLICATION_VERSION}
else 
docker build . ${EXTRA_DOCKER_OPTS} -t ${IMAGE_URL}:${APPLICATION_VERSION} -f ${DOCKERFILE} \
       --build-arg COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false --build-arg IDS_USER=${IDS_USER} \
       --build-arg IDS_TOKEN=${IDS_TOKEN}  --build-arg ARTIFACTORY_AUTH_BASE64=${ARTIFACTORY_AUTH_BASE64}  \
       --build-arg ARTIFACTORY_TOKEN_BASE64=${ARTIFACTORY_TOKEN_BASE64} --build-arg ARTIFACTORY_ID=${ARTIFACTORY_ID} \
       --build-arg ARTIFACTORY_API_KEY=${ARTIFACTORY_API_KEY}
fi
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker build command\"
    exit 1
fi

docker tag ${IMAGE_URL}:${APPLICATION_VERSION} ${IMAGE_URL}:latest
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker tag command\"
    exit 1
fi

docker push ${IMAGE_URL}:${APPLICATION_VERSION}
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker push command\"
    exit 1
fi

docker push ${IMAGE_URL}:latest
