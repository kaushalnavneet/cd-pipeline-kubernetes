#!/usr/bin/env bash
if [[ "${PIPELINE_DEBUG:-0}" == 1 ]]; then
    trap env EXIT
    env | sort
    set -x
fi

initDefaults() {
    export IMAGE_NAME=""
    export BUILD_CLUSTER=""
    export DOCKER_USERNAME="iamapikey"
    export EXTRA_DOCKER_OPTS="--no-cache"
    export ENVIRONMENT="development"
    export ARTIFACTORY_TOKEN_BASE64=""
    export ARTIFACTORY_AUTH_BASE64=""
    export ARTIFACTORY_API_KEY=""
    export RH_USERNAME=""
    export RH_PASSWORD=""
    export ARTIFACTORY_ID=""
    export ICD_REDIS_STORE=""
    export QR_STORE=""
    export MAVEN_USER_ID=""
    export ADD_CHGLOG_URL="false"
    export DOCKERFILE="cd-pipeline-kubernetes/docker/Dockerfile.nodejs14ubi"

    if [ -f "/config/CHARTS_REPO" ]; then
        export CHARTS_REPO=$(cat /config/CHARTS_REPO) 
    fi

    if [ -f "/config/DOCKERFILE" ]; then
        export DOCKERFILE=$(cat /config/DOCKERFILE) 
    fi

    if [ -f "/config/IMAGE_NAME" ]; then
        export IMAGE_NAME=$(cat /config/IMAGE_NAME) 
    fi

    if [ -f "/config/BUILD_CLUSTER" ]; then
        export BUILD_CLUSTER=$(cat /config/BUILD_CLUSTER) 
    fi

    if [ -f "/config/DOCKER_USERNAME" ]; then
        export DOCKER_USERNAME=$(cat /config/DOCKER_USERNAME) 
    fi

    if [ -f "/config/EXTRA_DOCKER_OPTS" ]; then
        export EXTRA_DOCKER_OPTS=$(cat /config/EXTRA_DOCKER_OPTS) 
    fi

    if [ -f "/config/ENVIRONMENT" ]; then
        export ENVIRONMENT=$(cat /config/ENVIRONMENT) 
    fi

    if [ -f "/config/ARTIFACTORY_TOKEN_BASE64" ]; then
        export ARTIFACTORY_TOKEN_BASE64=$(cat /config/ARTIFACTORY_TOKEN_BASE64) 
    fi

    if [ -f "/config/ARTIFACTORY_AUTH_BASE64" ]; then
        export ARTIFACTORY_AUTH_BASE64=$(cat /config/ARTIFACTORY_AUTH_BASE64) 
    fi

    if [ -f "/config/ARTIFACTORY_API_KEY" ]; then
        export ARTIFACTORY_API_KEY=$(cat /config/ARTIFACTORY_API_KEY)
    fi

    if [ -f "/config/ARTIFACTORY_ID" ]; then
        export ARTIFACTORY_ID=$(cat /config/ARTIFACTORY_ID) 
    fi

    if [ -f "/config/ICD_REDIS_STORE" ]; then
        export ICD_REDIS_STORE=$(cat /config/ICD_REDIS_STORE) 
    fi
    if [ -f "/config/QR_STORE" ]; then
        export QR_STORE=$(cat /config/QR_STORE) 
    fi

    if [ -f "/config/MAVEN_USER_ID" ]; then
        export MAVEN_USER_ID=$(cat /config/MAVEN_USER_ID) 
    fi
    if [ -f "/config/ADD_CHGLOG_URL" ]; then
        export ADD_CHGLOG_URL=$(cat /config/ADD_CHGLOG_URL) 
    fi

    if [ -f "/config/RH_PASSWORD" ]; then
        export RH_PASSWORD=$(cat /config/RH_PASSWORD)
    fi

    if [ -f "/config/RH_USERNAME" ]; then
        export RH_USERNAME=$(cat /config/RH_USERNAME)
    fi    
}

initEnvVars() {
    # grab env vars from config map
    if [ -f "/config/API" ]; then
        export API=$(cat /config/API)
    fi
    if [ -f "/config/REGION" ]; then
        export REGISTRY_REGION=$(cat /config/REGION)
    fi
    if [ -f "/config/API_KEY_1416501" ]; then
        export API_KEY=$(cat /config/API_KEY_1416501)
    fi
    if [ -f "/config/API_KEY_1416501" ]; then
        export DOCKER_PASSWORD=$(cat /config/API_KEY_1416501)
    fi
    if [ -f "/config/API_KEY_1308775" ]; then
        export API_KEY_1308775=$(cat /config/API_KEY_1308775)
    fi
    if [ -f "/config/API_KEY_1308775" ]; then
        export BUILD_CLUSTER_KEY=$(cat /config/API_KEY_1308775)
    fi
    if [ -f "/config/TOOLCHAIN_ID" ]; then
        export TOOLCHAIN_ID=$(cat /config/TOOLCHAIN_ID)
    fi
    if [ -f "/config/IDS_USER" ]; then
        export IDS_USER=$(cat /config/IDS_USER)
    fi
    if [ -f "/config/IDS_TOKEN" ]; then
        export IDS_TOKEN=$(cat /config/IDS_TOKEN)
    fi

    export  HOME="/root"
    if [ -f "/config/IMAGE_TAG" ]; then
            export APPLICATION_VERSION=$(cat /config/IMAGE_TAG) 
    fi

    if [ -f "/config/IMAGE_URL" ]; then
            export IMAGE_URL=$(cat /config/IMAGE_URL) 
    fi

    if [ -f "/config/REGISTRY_URL" ]; then
            export REGISTRY_URL=$(cat /config/REGISTRY_URL) 
    fi

    if [ -f "/config/REGISTRY_NAMESPACE" ]; then
            export REGISTRY_NAMESPACE=$(cat /config/REGISTRY_NAMESPACE) 
    fi

    if [ -f "/config/REGISTRY_REGION" ]; then
            export REGISTRY_REGION=$(cat /config/REGISTRY_REGION) 
    fi

    if [ -f "/config/SOURCE_DIRECTORY" ]; then
            export SOURCE_DIRECTORY=$(cat /config/SOURCE_DIRECTORY) 
    fi

    if [ -f "/config/DOCKERFILE" ]; then
            export DOCKERFILE=$(cat /config/DOCKERFILE) 
    fi

    if [ -f "/config/DOCKER_IMAGE" ]; then
            export DOCKER_IMAGE=$(cat /config/DOCKER_IMAGE) 
    fi

    export OPERATOR_SDK=""
}

# other env vars that used to be passed in to task, check they exist and use defaults otherwise
# init default values, overwrite if in config map too
initEnvVars

initDefaults

set -eo pipefail

cd "${WORKSPACE}/${SOURCE_DIRECTORY}"

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
echo ${APPLICATION_VERSION} > "${WORKSPACE}/appVersion"
echo "Building ${IMAGE_URL}:${APPLICATION_VERSION}"
echo ${APPLICATION_VERSION} > .pipeline_build_id
if [ "${ADD_CHGLOG_URL}" == true ]; then
    CHANGELOG_URL=",\"Changelog\" : \"https://github.ibm.com/org-ids/pipeline-changelog/blob/master/${SOURCE_DIRECTORY}/${GIT_COMMIT}.md\""
fi
echo "{\"build\": \"$TIMESTAMP\",\"commit\":\"$GIT_COMMIT\",\"appName\" : \"${COMPONENT_NAME}\",\"platform\" : \"Armada\"${CHANGELOG_URL}}" > build_info.json

docker login -u ${DOCKER_USERNAME} -p ${DOCKER_PASSWORD} ${IMAGE_URL%%/*}

echo "Dockerfile: ${DOCKERFILE}"
if [ "$OPERATOR_SDK" == true ]; then
    operator-sdk build ${IMAGE_URL}:${APPLICATION_VERSION}
else 
    docker build . ${EXTRA_DOCKER_OPTS} -t ${IMAGE_URL}:${APPLICATION_VERSION} -f ${DOCKERFILE} --build-arg \
    COMPONENT=${COMPONENT_NAME} --build-arg DEVELOPMENT=false --build-arg IDS_USER=${IDS_USER} --build-arg IDS_TOKEN=${IDS_TOKEN}  \
    --build-arg "ARTIFACTORY_TOKEN_BASE64=${ARTIFACTORY_TOKEN_BASE64}" --build-arg "ARTIFACTORY_AUTH_BASE64=${ARTIFACTORY_AUTH_BASE64}" \
    --build-arg "ARTIFACTORY_ID=${ARTIFACTORY_ID}" --build-arg "ICD_REDIS_STORE=${ICD_REDIS_STORE}" \
    --build-arg "QR_STORE=${QR_STORE}" --build-arg "MAVEN_USER_ID=${MAVEN_USER_ID}" \
    --build-arg "ARTIFACTORY_API_KEY=${ARTIFACTORY_API_KEY}" \
    --build-arg "RH_PASSWORD=${RH_PASSWORD}" --build-arg "RH_USERNAME=${RH_USERNAME}"

fi
if [ $? -ne 0 ]; then
    echo "Failed during execution of docker build command"
    exit 1
fi

docker tag ${IMAGE_URL}:${APPLICATION_VERSION} ${IMAGE_URL}:latest
if [ $? -ne 0 ]; then
    echo "Failed during execution of docker tag command"
    exit 1
fi

docker push ${IMAGE_URL}:${APPLICATION_VERSION}
if [ $? -ne 0 ]; then
    echo "Failed during execution of docker push command"
    exit 1
fi

docker push ${IMAGE_URL}:latest

DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE_URL}:${APPLICATION_VERSION}" | awk -F@ '{print $2}')"
echo "DIGEST"
echo -n "$DIGEST" > ${WORKSPACE}/image-digest
echo -n "$APPLICATION_VERSION" > ${WORKSPACE}/image-tags
echo -n "$IMAGE_URL" > ${WORKSPACE}/image

if which save_artifact >/dev/null; then
  echo "Save artifact: name=${IMAGE_URL} digest=${DIGEST}"
  save_artifact app-image type=image "name=${IMAGE_URL}" "digest=${DIGEST}"
fi
