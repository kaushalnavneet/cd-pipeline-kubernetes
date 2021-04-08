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
}

initEnvVars() {
    # grab env vars from config map
    export API=$(cat /config/API)
    export REGION=$(cat /config/REGION)
    export API_KEY=$(cat /config/API_KEY_1651315)
    export TOOLCHAIN_ID=$(cat /config/TOOLCHAIN_ID)
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
    echo "Skipping Deploy in integration pipeline"
    exit 0
fi
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
set +x