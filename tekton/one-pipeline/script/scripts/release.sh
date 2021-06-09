#!/usr/bin/env bash

#
# prepare data
#
set -eo pipefail

if [ -f "/config/DEV_MODE" ]; then
    export DEV_MODE=$(cat /config/DEV_MODE)
fi

initDefaults() {
    export DRY_RUN_CLUSTER="otc-us-south-dal13-stage"

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

    if [ -f "/config/ARTIFACTORY_API_KEY" ]; then
        export ARTIFACTORY_API_KEY=$(cat /config/ARTIFACTORY_API_KEY)
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
    if [ -f "/config/IMAGE_URL" ]; then
        export IMAGE_URL=$(cat /config/IMAGE_URL) 
    fi
}

initEnvVars() {
    # grab env vars from config map
    if [ -f "/config/API" ]; then
        export API=$(cat /config/API)
    fi

    if [ -f "/config/REGISTRY_REGION" ]; then
        export REGISTRY_REGION=$(cat /config/REGISTRY_REGION)
    fi

    if [ -f "/config/REGION" ]; then
        export REGION=$(cat /config/REGION)
    fi

    if [ -f "/config/IMAGE_URL" ]; then
        export API_KEY=$(cat /config/IMAGE_URL)
    fi

    if [ -f "/config/API_KEY_1308775" ]; then
        export DRY_RUN_API_KEY=$(cat /config/API_KEY_1308775)
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

    if [ -f "/config/git-commit" ]; then
        export COMMIT_SHA="$(cat /config/git-commit)"
    fi

    if [ -f "/config/repository-url" ]; then
        export APP_REPO="$(cat /config/repository-url)"
    fi

    if [ -f "/config/app-name" ]; then
        export APP_NAME="$(cat /config/app-name)"
    fi

    if [ -f "/config/git-token" ]; then
        export GHE_TOKEN="$(cat ../git-token)"
    fi

    if [ -f "/config/inventory-url" ]; then
        INVENTORY_REPO="$(cat /config/inventory-url)"
        GHE_ORG=${INVENTORY_REPO%/*}
        export GHE_ORG=${GHE_ORG##*/}
        GHE_REPO=${INVENTORY_REPO##*/}
        export GHE_REPO=${GHE_REPO%.git}
    fi

    if [ -f "/config/SOURCE_DIRECTORY" ]; then
        export WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
    fi

    if [ -f "/config/PIPELINE_CHARTS_REPO" ]; then
        export PIPELINE_CHARTS_REPO=$(cat /config/PIPELINE_CHARTS_REPO)
    fi
 }

# other env vars that used to be passed in to task, check they exist and use defaults otherwise
# init default values, overwrite if in config map too


initEnvVars

initDefaults

if [[ -z $DEV_MODE ]]; then
    CHART_REPO=$( basename "${PIPELINE_CHARTS_REPO}" .git )
    CHART_ORG=$(cat ${WORKSPACE}/${WORK_DIR}/chart_org)
    CHART_VERSION=$(cat ${WORKSPACE}/${WORK_DIR}/chart_version)
    
    echo "CHART_VERSION: ${CHART_VERSION}"
    echo "CHART_ORG: ${CHART_ORG}"

    echo "Adding to inventory"
    ARTIFACT="https://github.ibm.com/$CHART_ORG/$CHART_REPO/blob/master/charts/$APP_NAME-$CHART_VERSION.tgz"
    IMAGE_ARTIFACT="$(get_env artifact)"
    SIGNATURE="$(get_env signature "")"

    # Install cocoa cli
    function installCocoa() {
        local cocoaVersion=1.7.0
        echo "Installing cocoa cli $cocoaVersion"
        curl -u ${ARTIFACTORY_ID}:${ARTIFACTORY_API_KEY} -O "https://eu.artifactory.swg-devops.com/artifactory/wcp-compliance-automation-team-generic-local/cocoa-linux-${cocoaVersion}"
        cp cocoa-linux-* /usr/local/bin/cocoa
        chmod +x /usr/local/bin/cocoa
        export PATH="$PATH:/usr/local/bin/"
        echo "Done"
        echo
    }
    INVENTORY_BRANCH="staging"
    
    installCocoa
    cocoa inventory add \
        --environment="${INVENTORY_BRANCH}" \
        --artifact="${ARTIFACT}" \
        --repository-url="${APP_REPO}" \
        --commit-sha="${COMMIT_SHA}" \
        --build-number="${BUILD_NUMBER}" \
        --pipeline-run-id="${PIPELINE_RUN_ID}" \
        --version="$(get_env version)" \
        --name="${APP_NAME}" \
        --type="chart"
    cocoa inventory add \
        --environment="${INVENTORY_BRANCH}" \
        --artifact="${IMAGE_ARTIFACT}" \
        --repository-url="${APP_REPO}" \
        --commit-sha="${COMMIT_SHA}" \
        --build-number="${BUILD_NUMBER}" \
        --pipeline-run-id="${PIPELINE_RUN_ID}" \
        --version="$(get_env version)" \
        --name="${APP_NAME}_image" \
        --signature="${SIGNATURE}" \
        --type="image" \
        --provenance="${IMAGE_ARTIFACT}" \
        --sha256="$(echo -n ${IMAGE_ARTIFACT} | cut -d ':' -f 2)"

    echo "Inventory updated"
else 
   echo "Dev Mode - skipping"
fi