#!/usr/bin/env bash
if [[ "${PIPELINE_DEBUG:-0}" == 1 ]]; then
    trap env EXIT
    env | sort
    set -x
fi

# grab env vars from config map
API=$(cat /config/API)
REGISTRY_REGION=$(cat /config/REGION)
API_KEY=$(cat /config/API_KEY_1416501)
DOCKER_PASSWORD=$(cat /config/API_KEY_1416501)
API_KEY_1308775=$(cat /config/API_KEY_1308775)
BUILD_CLUSTER_KEY=$(cat /config/API_KEY_1308775)
TOOLCHAIN_ID=$(cat /config/TOOLCHAIN_ID)
IDS_USER=$(cat /config/IDS_USER)
IDS_TOKEN=$(cat /config/IDS_TOKEN)
# other env vars that used to be passed in to task
HOME="/root"
IMAGE_NAME=$(cat /config/IMAGE_NAME)
echo $IMAGE_NAME
        # value: $(params.imageName)
# IMAGE_TAG
#         value: $(params.imageTag)
# APPLICATION_VERSION
#         value: $(params.imageTag)
# IMAGE_URL=$(cat /config/IMAGE_URL)
# REGISTRY_URL
#         value: $(params.registryUrl)
# REGISTRY_NAMESPACE
#         value: $(params.registryNamespace)
# REGISTRY_REGION
#         value: $(params.registryRegion)
# SOURCE_DIRECTORY
#         value: $(params.source_directory)
# DOCKERFILE
#         value: $(params.dockerFile)
# DOCKER_IMAGE
#         value: $(params.runBaseImage)
# DOCKER_USERNAME
#         value: $(params.dockerUsername)
# EXTRA_DOCKER_OPTS
#         value: $(params.extraDockerOpts)
# BUILD_CLUSTER
#         value: $(params.buildCluster)
# ENVIRONMENT
#         value: $(params.environment)
#       # used for pipeline-ui build
# ARTIFACTORY_TOKEN_BASE64
#         value: $(params.artifactoryTokenBase64)
# ARTIFACTORY_ID
#         value: $(params.artifactoryId)
# CONSOLE_AUTH_TOKEN
#         value: $(params.consoleAuthToken)
#       # can we get rid of this?
# OPERATOR_SDK
#         value: ''
# ICD_REDIS_STORE
#         value: $(params.icd-redis-store)
# QR_STORE
#         value: $(params.qr-store)
# DOCKER_HOST
#         value: "unix:///var/run/docker.sock"
# MAVEN_USER_ID
#         value: $(params.mavenUserId)
# ADD_CHGLOG_URL
#         value: $(params.addChglogUrl)

export HOME=/root
[ -f /root/.nvm/nvm.sh ] && source /root/.nvm/nvm.sh
set -e
cd "${SOURCE_DIRECTORY}"
#[ -d /work ] && [ -d cd-pipeline-kubernetes ] && rm -rf cd-pipeline-kubernetes
#[ -d /work ] && cp -a /work cd-pipeline-kubernetes
ibmcloud config --check-version=false
ibmcloud plugin install -f container-registry
ibmcloud plugin install -f kubernetes-service
ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${BUILD_CLUSTER_KEY}
ibmcloud cr login

IMAGE_URL=${IMAGE_URL:-${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}
DOCKERFILE=${DOCKERFILE:-cd-pipeline-kubernetes/docker/Dockerfile.${DOCKER_IMAGE##*:}}
[ -f build.properties ] && source build.properties

echo "Building using local Docker"

TIMESTAMP=$(date +%Y%m%d%H%M%Z)
if [ -z "$GIT_COMMIT" ]; then
    GIT_COMMIT=$(git rev-parse --verify HEAD)
fi

if [ -z "$APPLICATION_VERSION" ]; then
    APPLICATION_VERSION="${GIT_COMMIT}-${TIMESTAMP}"
fi
echo ${APPLICATION_VERSION} > /workspace/appVersion
echo "Building ${IMAGE_URL}:${APPLICATION_VERSION}"
echo ${APPLICATION_VERSION} > .pipeline_build_id
if [ "${ADD_CHGLOG_URL}" == true ]; then
    CHANGELOG_URL=",\"Changelog\" : \"https://github.ibm.com/org-ids/pipeline-changelog/blob/master/${SOURCE_DIRECTORY}/${GIT_COMMIT}.md\""
fi
echo "{\"build\": \"$TIMESTAMP\",\"commit\":\"$GIT_COMMIT\",\"appName\" : \"${COMPONENT_NAME}\",\"platform\" : \"Armada\"${CHANGELOG_URL}}" > build_info.json

docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ${IMAGE_URL%%/*}
# For some reason this doesn't get repulled in docker engine
#docker pull ${DOCKER_IMAGE}
if [ $? -ne 0 ]; then
    echo \"Failed during execution of docker pull command\"
    exit 1
fi

echo "Dockerfile: ${DOCKERFILE}"
if [ "$OPERATOR_SDK" == true ]; then
    operator-sdk build ${IMAGE_URL}:${APPLICATION_VERSION}
else 
    docker build . ${EXTRA_DOCKER_OPTS} -t ${IMAGE_URL}:${APPLICATION_VERSION} -f ${DOCKERFILE} --build-arg \
    COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false --build-arg IDS_USER=${IDS_USER} --build-arg IDS_TOKEN=${IDS_TOKEN}  \
    --build-arg "ARTIFACTORY_TOKEN_BASE64=${ARTIFACTORY_TOKEN_BASE64}" --build-arg "ARTIFACTORY_ID=${ARTIFACTORY_ID}" \
    --build-arg "CONSOLE_AUTH_TOKEN=${CONSOLE_AUTH_TOKEN}" --build-arg "ICD_REDIS_STORE=${ICD_REDIS_STORE}" \
    --build-arg "QR_STORE=${QR_STORE}" --build-arg "MAVEN_USER_ID=${MAVEN_USER_ID}"

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