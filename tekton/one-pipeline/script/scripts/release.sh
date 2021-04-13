#!/usr/bin/env bash

#
# prepare data
#

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
    if [ -f "/config/IMAGE_URL" ]; then
        export IMAGE_URL=$(cat /config/IMAGE_URL) 
    fi
}

initEnvVars() {
    # grab env vars from config map
    export API=$(cat /config/API)
    export REGISTRY_REGION=$(cat /config/REGION)
    export API_KEY=$(cat /config/API_KEY_1416501)
    export DRY_RUN_API_KEY=$(cat /config/API_KEY_1308775)
    export DOCKER_PASSWORD=$(cat /config/API_KEY_1416501)
    export API_KEY_1308775=$(cat /config/API_KEY_1308775)
    export BUILD_CLUSTER_KEY=$(cat /config/API_KEY_1308775)
    export TOOLCHAIN_ID=$(cat /config/TOOLCHAIN_ID)
    export IDS_USER=$(cat /config/IDS_USER)
    export IDS_TOKEN=$(cat /config/IDS_TOKEN)
    export MAJOR_VERSION=$(cat /config/MAJOR_VERSION)
    export MINOR_VERSION=$(cat /config/MINOR_VERSION)
    export RELEASE_ENVIRONMENT=$(cat /config/RELEASE_ENVIRONMENT)
    export CLUSTERNAMESPACE=$(cat /config/CLUSTERNAMESPACE)
}

# other env vars that used to be passed in to task, check they exist and use defaults otherwise
# init default values, overwrite if in config map too


initEnvVars

initDefaults

if [[ -z $DEV_MODE ]]; then
    export GHE_TOKEN="$(cat ../git-token)"
    export COMMIT_SHA="$(cat /config/git-commit)"
    export APP_NAME="$(cat /config/app-name)"

    INVENTORY_REPO="$(cat /config/inventory-url)"
    GHE_ORG=${INVENTORY_REPO%/*}
    export GHE_ORG=${GHE_ORG##*/}
    GHE_REPO=${INVENTORY_REPO##*/}
    export GHE_REPO=${GHE_REPO%.git}

    set +e
    REPOSITORY="$(cat /config/repository)"
    TAG="$(cat /config/custom-image-tag)"
    set -e

    export APP_REPO="$(cat /config/repository-url)"
    APP_REPO_ORG=${APP_REPO%/*}
    export APP_REPO_ORG=${APP_REPO_ORG##*/}

    if [[ "${REPOSITORY}" ]]; then
        export APP_REPO_NAME=$(basename $REPOSITORY .git)
        APP_NAME=$APP_REPO_NAME
    else
        APP_REPO_NAME=${APP_REPO##*/}
        export APP_REPO_NAME=${APP_REPO_NAME%.git}
    fi
    set -x
    WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
    cd /workspace/app/${WORK_DIR}

    IDS_TOKEN=$(cat /config/IDS_TOKEN)
    echo "echo -n $IDS_TOKEN" > ./token.sh
    chmod +x ./token.sh

    GIT_ASKPASS=./token.sh git clone --single-branch --branch master https://github.ibm.com/org-ids/pipeline-config.git

    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service
    ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${API_KEY}
    
    IMAGE_URL=${IMAGE_URL:-${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}}

    if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        APPLICATION_VERSION=$( cat /workspace/app/appVersion )
        if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        ibmcloud cr images --restrict ${IMAGE_NAMESPACE}/${APP_NAME} > _allImages
        APPLICATION_VERSION=$(cat _allImages | grep $(cat _allImages | grep latest | awk '{print $3}') | grep -v latest | awk '{print $2}')
        fi
    fi
    git config --global user.email "idsorg@us.ibm.com"
    git config --global user.name "IDS Organization"
    git config --global push.default matching

    CHART_REPO=$( basename https://github.ibm.com/org-ids/pipeline-config.git .git )
    CHART_REPO_ABS=$(pwd)/${CHART_REPO}
    CHART_VERSION=$(ls -v ${CHART_REPO_ABS}/charts/${APP_NAME}* 2> /dev/null | tail -n -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | awk -F'.' -v OFS='.' '{$3=sprintf("%d",++$3)}7' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")
    CHART_VERSION=${CHART_VERSION:=1.0.0}

    printf "Publishing chart ${APP_NAME},\nversion ${CHART_VERSION},\nfor cluster ${DRY_RUN_CLUSTER},\nnamespace ${CLUSTERNAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}\n"

    ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${DRY_RUN_API_KEY}

    set +e
    function cluster_config() {
        # 1 - cluster name
        for iteration in {1..30}
        do
            echo "Running cluster config for cluster $1: $iteration / 30"
            ibmcloud ks cluster config --cluster $1
            if [[ $? -eq 0 ]]; then
                return 0
            else
                echo "Cluster config for $1 failed. Trying again..."
                sleep 5
            fi
        done
        return 1
    }
    cluster_config ${DRY_RUN_CLUSTER}
    set -e

    if [ -z "${MAJOR_VERSION}" ] ||  [ -z "${MINOR_VERSION}" ] ||  [ -z "${CHART_REPO}" ]; then
        echo "Major & minor version and chart repo vars need to be set"
        exit 1
    fi


    #specific tag
    tmp=$(mktemp)
    yq --yaml-output --arg appver "${APPLICATION_VERSION}" '.pipeline.image.tag=$appver' ${APP_NAME}/values.yaml > "$tmp" && mv "$tmp" ${APP_NAME}/values.yaml

    #specific image
    yq --yaml-output --arg image "${IMAGE_URL}" '.pipeline.image.repository=$image' ${APP_NAME}/values.yaml > "$tmp" && mv "$tmp" ${APP_NAME}/values.yaml

    yq --yaml-output --arg chartver "${CHART_VERSION}" '.version=$chartver' ${APP_NAME}/Chart.yaml > "$tmp" && mv "$tmp" ${APP_NAME}/Chart.yaml

    helm init -c --stable-repo-url https://charts.helm.sh/stable
    helm dep up ${APP_NAME}
    echo "=========================================================="
    echo -e "Dry run into: ${DRY_RUN_CLUSTER}/${CLUSTERNAMESPACE}."
    if helm upgrade ${APP_NAME} ${APP_NAME} --namespace ${CLUSTERNAMESPACE} --set tags.environment=false --set ${RELEASE_ENVIRONMENT}.enabled=true --install --dry-run --debug; then
        echo "helm upgrade --dry-run done"
    else
        echo "helm upgrade --dry-run failed"
        exit 1
    fi

    echo "Packaging Helm Chart"

    pushd ${CHART_REPO_ABS}
    CHART_ORG=$( git remote -v | grep push | cut -f4 -d/ )
    popd

    n=0
    rc=0
    ORIG_DIR=$(pwd)
    until [ $n -ge 5 ]
    do
        echo "git pull"
        git -C $CHART_REPO_ABS pull --no-edit
        echo "git pull done"
        mkdir -p $CHART_REPO_ABS/charts
        helm package ${APP_NAME} -d $CHART_REPO_ABS/charts

        git add -A .
        git commit -m "${APPLICATION_VERSION}"
        git push
        rc=$?
        if [[ $rc == 0 ]]; then 
            break;
        fi
        n=$[$n+1]
        cd $ORIG_DIR
        rm -fr $CHART_REPO_ABS
        mkdir -p $CHART_REPO_ABS
        echo "Clone charts repo"
        GIT_ASKPASS=./token.sh git clone https://github.ibm.com/$CHART_ORG/$CHART_REPO $CHART_REPO_ABS
        echo "Done cloning charts repo"
    done

    if [[ $rc != 0 ]]; then exit $rc; fi

    echo "Adding to inventory"
    CHART_VERSION=$(yq r -j "$APP_NAME/Chart.yaml" | jq -r '.version')
    ARTIFACT="https://github.ibm.com/$CHART_ORG/$CHART_REPO/blob/master/charts/$APP_NAME-$CHART_VERSION.tgz"
    IMAGE_ARTIFACT="$(get_env artifact)"
    SIGNATURE="$(get_env signature "")"

    if [ "$SIGNATURE" ]; then
        # using TaaS worker
        APP_ARTIFACTS='{ "signature": "'${SIGNATURE}'", "provenance": "'${IMAGE_ARTIFACT}'" }'
    else
        # using regular worker, no signature
        APP_ARTIFACTS='{ "provenance": "'${IMAGE_ARTIFACT}'" }'
    fi

    # Install cocoa cli
    function installCocoa() {
        local cocoaVersion=1.5.0
        echo "Installing cocoa cli $cocoaVersion"
        curl -u ${ARTIFACTORY_ID}:${ARTIFACTORY_API_KEY} -O "https://eu.artifactory.swg-devops.com/artifactory/wcp-compliance-automation-team-generic-local/cocoa-linux-${cocoaVersion}"
        cp cocoa-linux-* /usr/local/bin/cocoa
        chmod +x /usr/local/bin/cocoa
        export PATH="$PATH:/usr/local/bin/"
        echo "Done"
        echo
    }
    
    installCocoa
    cocoa inventory add \
        --environment="${INVENTORY_BRANCH}" \
        --artifact="${ARTIFACT}" \
        --repository-url="${APP_REPO}" \
        --commit-sha="${COMMIT_SHA}" \
        --build-number="${BUILD_NUMBER}" \
        --pipeline-run-id="${PIPELINE_RUN_ID}" \
        --version="$(get_env version)" \
        --name="${APP_NAME}"
    cocoa inventory add \
        --environment="${INVENTORY_BRANCH}" \
        --artifact="${IMAGE_ARTIFACT}" \
        --repository-url="${APP_REPO}" \
        --commit-sha="${COMMIT_SHA}" \
        --build-number="${BUILD_NUMBER}" \
        --pipeline-run-id="${PIPELINE_RUN_ID}" \
        --version="$(get_env version)" \
        --name="${APP_NAME}_image" \
        --app-artifacts="${APP_ARTIFACTS}"
    echo "Inventory updated"
else 
    echo "Dev Mode - skipping"
fi