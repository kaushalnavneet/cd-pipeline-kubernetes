#!/usr/bin/env bash
if [[ "${PIPELINE_DEBUG:-0}" == 1 ]]; then
    trap env EXIT
    env | sort
    set -x
fi

initDefaults() {
   
    export REGISTRY_URL="us.icr.io"
    export REGISTRY_NAMESPACE="opentoolchain"
    export REGISTRY_REGION="us-south"
    export IMAGE_NAME=""
    export CLUSTER_NAME="otc-us-south-dev"
    export CLUSTER_NAMESPACE="opentoolchain"
    export ENVIRONMENT="development"
    export SKIP="false"
    export HELM_OPTIONS=""
    export APPLICATION_VERSION=""

    if [ -f "/config/REGISTRY_URL" ]; then
        export REGISTRY_URL=$(cat /config/REGISTRY_URL) 
    fi

    if [ -f "/config/REGISTRY_NAMESPACE" ]; then
        export REGISTRY_NAMESPACE=$(cat /config/REGISTRY_NAMESPACE) 
    fi

    if [ -f "/config/REGISTRY_REGION" ]; then
            export REGISTRY_REGION=$(cat /config/REGISTRY_REGION) 
    fi

    if [ -f "/config/IMAGE_NAME" ]; then
        export IMAGE_NAME=$(cat /config/IMAGE_NAME) 
    fi

    if [ -f "/config/IMAGE_TAG" ]; then
        export APPLICATION_VERSION=$(cat /config/IMAGE_TAG) 
    fi

    if [ -f "/config/CLUSTER_NAME" ]; then
        export CLUSTER_NAME=$(cat /config/CLUSTER_NAME) 
    fi

    if [ -f "/config/CLUSTER_NAMESPACE" ]; then
        export CLUSTER_NAMESPACE=$(cat /config/CLUSTER_NAMESPACE) 
    fi

    if [ -f "/config/ENVIRONMENT" ]; then
        export ENVIRONMENT=$(cat /config/ENVIRONMENT) 
    fi
    if [ -f "/config/SKIP" ]; then
        export SKIP=$(cat /config/SKIP) 
    fi

    if [ -f "/config/HELM_OPTIONS" ]; then
        export HELM_OPTIONS=$(cat /config/HELM_OPTIONS) 
    fi
    if [ -f "/config/DEV_MODE" ]; then
        export DEV_MODE=$(cat /config/DEV_MODE) 
    fi
}

initEnvVars() {
    # grab env vars from config map
    export DRY_RUN_CLUSTER="otc-us-south-dal13-stage"
    
    export API=$(cat /config/API)
    export REGION=$(cat /config/REGION)
    export API_KEY=$(cat /config/API_KEY_1651315)

    export TOOLCHAIN_ID=$(cat /config/TOOLCHAIN_ID)

    export REGISTRY_REGION=$(cat /config/REGISTRY_REGION)
    export DRY_RUN_API_KEY=$(cat /config/API_KEY_1308775)
    export DOCKER_PASSWORD=$(cat /config/API_KEY_1416501)
    export API_KEY_1308775=$(cat /config/API_KEY_1308775)
    export BUILD_CLUSTER_KEY=$(cat /config/API_KEY_1308775)
    export IDS_USER=$(cat /config/IDS_USER)
    export IDS_TOKEN=$(cat /config/IDS_TOKEN)
    export CLUSTERNAMESPACE=$(cat /config/CLUSTERNAMESPACE)
    export MAJOR_VERSION=$(cat /config/MAJOR_VERSION)
    export MINOR_VERSION=$(cat /config/MINOR_VERSION)
    export RELEASE_ENVIRONMENT=$(cat /config/RELEASE_ENVIRONMENT)

    export CHARTS_DIRECTORY="pipeline-config"

    source "${WORKSPACE}/${ONE_PIPELINE_CONFIG_DIRECTORY_NAME}/tekton/one-pipeline/script/scripts/helpers.sh"
    export CLUSTER_NAME1=$(cat /config/cluster_name1)
    export CLUSTER_NAME2=$(cat /config/cluster_name2)
    export CLUSTER_NAME3=$(cat /config/cluster_name3)
}

# other env vars that used to be passed in to task, check they exist and use defaults otherwise
# init default values, overwrite if in config map too

initEnvVars

initDefaults

export  HOME="/root"


if [ -f "/config/IMAGE_URL" ]; then
        export IMAGE_URL=$(cat /config/IMAGE_URL) 
fi

if [ -f "/config/IMAGE_NAME" ]; then
        export IMAGE_NAME=$(cat /config/IMAGE_NAME) 
fi

if [ -f "/config/SOURCE_DIRECTORY" ]; then
        export SOURCE_DIRECTORY=$(cat /config/SOURCE_DIRECTORY) 
fi



export HOME=/root
[ -f /root/.nvm/nvm.sh ] && source /root/.nvm/nvm.sh
set -e
if [ "${SKIP}" == true ]; then
    echo "Skipping Deploy"
    exit 0
fi

if [[ -z $DEV_MODE ]]; then
    export GHE_TOKEN="$(cat ../git-token)"
    export COMMIT_SHA="$(cat /config/git-commit)"
    export APP_NAME="$(cat /config/app-name)"

    set +e
    REPOSITORY="$(cat /config/repository)"
    TAG="$(cat /config/custom-image-tag)"
    set -e

    set -x
    WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
    cd ${WORKSPACE}/${WORK_DIR}

    IDS_TOKEN=$(cat /config/IDS_TOKEN)
    echo "echo -n $IDS_TOKEN" > ./token.sh
    chmod +x ./token.sh

    GIT_ASKPASS=./token.sh git clone --single-branch --branch master https://github.ibm.com/org-ids/pipeline-config.git

    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service
    
    IMAGE_URL=${IMAGE_URL:-${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}}

    git config --global user.email "idsorg@us.ibm.com"
    git config --global user.name "IDS Organization"
    git config --global push.default matching

    CHART_REPO=$( basename https://github.ibm.com/org-ids/pipeline-config.git .git )
    CHART_REPO_ABS=$(pwd)/${CHART_REPO}
    CHART_VERSION=$(ls ${CHART_REPO_ABS}/charts/${APP_NAME}* 2> /dev/null | sort -V | tail -n -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | awk -F'.' -v OFS='.' '{$3=sprintf("%d",++$3)}7' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")
    CHART_VERSION=${CHART_VERSION:=1.0.0}

    printf "Publishing chart ${APP_NAME},\nversion ${CHART_VERSION},\nfor cluster ${DRY_RUN_CLUSTER},\nnamespace ${CLUSTERNAMESPACE}.\n"

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
    set -eo pipefail

    if [ -z "${MAJOR_VERSION}" ] ||  [ -z "${MINOR_VERSION}" ] ||  [ -z "${CHART_REPO}" ]; then
        echo "Major & minor version and chart repo vars need to be set"
        exit 1
    fi


    #specify tag
    yq write -i ${APP_NAME}/values.yaml pipeline.image.tag=$appver "${APPLICATION_VERSION}"

    #specify image
    yq write -i ${APP_NAME}/values.yaml pipeline.image.repository "${IMAGE_URL}"

    #specify version
    yq write -i ${APP_NAME}/Chart.yaml version "${CHART_VERSION}"

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
    echo "CHART_ORG=${CHART_ORG}"
    echo -n "${CHART_ORG}" > ${WORKSPACE}/${WORK_DIR}/chart_org
    popd

    APPLICATION_VERSION=$(cat ${WORKSPACE}/image-tags)
    echo -n "${CHART_VERSION}" > ${WORKSPACE}/${WORK_DIR}/chart_version
    n=0
    rc=0
    ORIG_DIR=$(pwd)
    until [ $n -ge 5 ]
    do
        echo "git pull"
        GIT_ASKPASS=${WORKSPACE}/${WORK_DIR}/token.sh git -C $CHART_REPO_ABS pull --no-edit
        echo "git pull done"
        mkdir -p $CHART_REPO_ABS/charts
        helm package ${APP_NAME} -d $CHART_REPO_ABS/charts

        cd $CHART_REPO_ABS
        git add -A .
        git commit -m "${APPLICATION_VERSION}"
        GIT_ASKPASS=${WORKSPACE}/${WORK_DIR}/token.sh git push
        rc=$?
        if [[ $rc == 0 ]]; then 
            break;
        fi
        n=$[$n+1]
        cd $ORIG_DIR
        rm -fr $CHART_REPO_ABS
        mkdir -p $CHART_REPO_ABS
        echo "Clone charts repo"
        GIT_ASKPASS=/workspace/app/${WORK_DIR}/token.sh git clone https://github.ibm.com/$CHART_ORG/$CHART_REPO $CHART_REPO_ABS
        echo "Done cloning charts repo"
    done

    if [[ $rc != 0 ]]; then exit $rc; fi

    # need to deploy to preprod environment
    deployComponent "${APP_NAME}" "${CLUSTER_NAME1}" "${CLUSTERNAMESPACE}" "${REGION}"
    deployComponent "${APP_NAME}" "${CLUSTER_NAME2}" "${CLUSTERNAMESPACE}" "${REGION}"
    deployComponent "${APP_NAME}" "${CLUSTER_NAME3}" "${CLUSTERNAMESPACE}" "${REGION}"
else
    echo "1"
    pwd
    ls

    cd /workspace/app
    cd "${SOURCE_DIRECTORY}"
    WORKDIR=${WORKDIR:-/work}

    echo "2"
    pwd
    ls

    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service
    ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${API_KEY}

    IMAGE_URL=${IMAGE_URL:-${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}}
    COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}

    if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        APPLICATION_VERSION=$( cat /workspace/app/appVersion )
        if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        ibmcloud cr images --restrict ${IMAGE_NAMESPACE}/${COMPONENT_NAME} > _allImages
        APPLICATION_VERSION=$(cat _allImages | grep $(cat _allImages | grep latest | awk '{print $3}') | grep -v latest | awk '{print $2}')
        fi
    fi

    printf "Deploying release ${COMPONENT_NAME} into cluster ${CLUSTER_NAME},\nnamespace ${CLUSTER_NAMESPACE},\nwith image: ${IMAGE_URL}:${APPLICATION_VERSION}.\n"

    #[ -d /work ] && [ -d cd-pipeline-kubernetes ] && rm -rf cd-pipeline-kubernetes
    #[ -d /work ] && cp -a /work cd-pipeline-kubernetes
    #[ ! -d devops-config ] && cp cd-pipeline-kubernetes/devops-config .
    echo directory status
    pwd
    ls -F
    ls -F cd-pipeline-kubernetes

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
    cluster_config ${CLUSTER_NAME}

    set -e
    INGRESS_SUBDOMAIN=$(ibmcloud ks cluster get -s --cluster ${CLUSTER_NAME} | grep -i "Ingress subdomain:" | awk '{print $3;}')
    echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
    if [[ ${INGRESS_SUBDOMAIN} == *,* ]];then
        INGRESS_SUBDOMAIN=$(echo "$INGRESS_SUBDOMAIN" | cut -d',' -f1)
        echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
    fi

    INGRESS_SECRET=$(ibmcloud ks cluster get -s --cluster ${CLUSTER_NAME} | grep -i "Ingress secret:" | awk '{print $3;}')
    if [[ ${INGRESS_SECRET} == *,* ]];then
        INGRESS_SECRET=$(echo "$INGRESS_SECRET" | cut -d',' -f1)
        echo "INGRESS SECRET: $INGRESS_SECRET"
    fi

    tmp=$(mktemp)
    yq --yaml-output --arg stagename "${COMPONENT_NAME}" '. | .pipeline.fullnameOverride=$stagename | .pipeline.nameOverride=$stagename' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

    helm version
    kubectl version
    helm ls
    helm init -c --stable-repo-url https://charts.helm.sh/stable
    helm dep up ${COMPONENT_NAME}
    set -x
    set +e
    chartExists=$(helm list ${COMPONENT_NAME})
    if [ -z $chartExists ]; then
        deleted=$(helm list --all ${COMPONENT_NAME} | grep DELETED)
        echo "DELETED HELM: $deleted"
        set -e
        if [ ! -z "$deleted" ]; then
        helm delete --purge ${COMPONENT_NAME}
        fi
        helm install ${HELM_OPTIONS} --name ${COMPONENT_NAME} ${COMPONENT_NAME} --namespace ${CLUSTER_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_URL} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
    else
        set -e
        helm upgrade ${HELM_OPTIONS} --force ${COMPONENT_NAME} ${COMPONENT_NAME} --install --namespace ${CLUSTER_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_URL} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
    fi
fi