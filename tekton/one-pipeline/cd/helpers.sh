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

function deployComponent() {
    set -eo pipefail
    cd "${SOURCE_DIRECTORY}"
    WORKDIR=${WORKDIR:-/work}
    VALUES_OPT=""

    if [ -z "$REGISTRY_API_KEY" ]; then
        REGISTRY_API_KEY=$API_KEY
    fi
    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service
    echo "Logging in to us.icr.io"
    ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${REGISTRY_API_KEY}

    if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        [ -r /workspace/appVersion ] && APPLICATION_VERSION=$( cat /workspace/appVersion )
        if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
            ibmcloud cr images --restrict ${REGISTRY_NAMESPACE}/${COMPONENT_NAME} > _allImages
            APPLICATION_VERSION=$(cat _allImages | grep $(cat _allImages | grep latest | awk '{print $3}') | grep -v latest | awk '{print $2}')
        fi
    fi

    printf "Deploying release ${COMPONENT_NAME} into cluster ${CLUSTER_NAME},\nnamespace ${CLUSTER_NAMESPACE},\nwith image: ${IMAGE_URL}:${APPLICATION_VERSION}.\n"

    echo Current Directory: $(pwd)

    echo Logging into Deployment account
    ibmcloud login --apikey ${API_KEY} -r ${REGION}

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

    set -eo pipefail
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

    CHART_PATH=$( ls -v charts/"${COMPONENT_NAME}"*.tgz |  tail -n 1 )
    echo Expanding "$CHART_PATH"
    if [ ! -e tmp/${COMPONENT_NAME} ]; then
        mkdir -p tmp ; cd tmp
        tar zxf ../$CHART_PATH
        cd ..
        # pick up the environment values fresh if available
        echo "component name=${COMPONENT_NAME}"
        echo "environment=${ENVIRONMENT}"
        echo "current dir=$(pwd)"
        [ -r "../devops-config/environments/${ENVIRONMENT}/values.yaml" ] && \
        cp ../devops-config/environments/${ENVIRONMENT}/values.yaml tmp/${COMPONENT_NAME}/charts/${ENVIRONMENT}
    fi

    set +e
    #helm version
    chartExists=$(helm list ${COMPONENT_NAME})
    if [ -z $chartExists ]; then
        deleted=$(helm list --all ${COMPONENT_NAME} | grep DELETED)
        echo "DELETED HELM: $deleted"
        if [ ! -z "$deleted" ]; then
        helm delete --purge ${COMPONENT_NAME}
        fi
        set -e
        echo "helm install --name ${COMPONENT_NAME} tmp/${COMPONENT_NAME} ${VALUES_OPT} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true  \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN}"
        helm install --name ${COMPONENT_NAME} tmp/${COMPONENT_NAME} ${VALUES_OPT} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true  \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
    else
        set -e
        echo "helm upgrade --force ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --install ${VALUES_OPT} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN}"
        helm upgrade --force ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --install ${VALUES_OPT} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
    fi
}