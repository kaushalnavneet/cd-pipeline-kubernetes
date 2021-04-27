function cluster_config() {
    set +e
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

function get_chart_name() {
    # 1 - conponent name
    echo $(cat "${WORKSPACE}/${INVENTORY_REPO_DIRECTORY_NAME}/${1}" | jq -r .artifact | cut -d / -f9)
}

function deployComponent() {
    # 1 - component name
    # 2 - cluster name
    # 3 - cluster namespace
    # 4 - environment
    COMPONENT_NAME="$1"
    CLUSTER_NAME="$2"
    CLUSTER_NAMESPACE="$3"
    ENVIRONMENT="$4"
    CLUSTER_REGION="$4"

    set -eo pipefail
    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service

    printf "Deploying release ${COMPONENT_NAME} into cluster ${CLUSTER_NAME},\nnamespace ${CLUSTER_NAMESPACE}\n"

    echo Current Directory: $(pwd)

    echo Logging into Deployment account
    ibmcloud login --apikey ${API_KEY} -r ${CLUSTER_REGION}

    if ! cluster_config ${CLUSTER_NAME}; then
        echo "Failed to configure the cluster ${CLUSTER_NAME}"
       return 1
    fi

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

    CHART_NAME=$(get_chart_name "${COMPONENT_NAME}")
    echo Expanding "$CHART_PATH"
    if [ ! -e tmp/${COMPONENT_NAME} ]; then
        mkdir -p tmp ; cd tmp
        echo "Expanding charts to tmp"
        tar zxf "${WORKSPACE}/${CHARTS_DIRECTORY}/charts/$CHART_NAME"
        cd ..
        # pick up the environment values fresh if available
        echo "component name=${COMPONENT_NAME}"
        echo "environment=${ENVIRONMENT}"
        echo "current dir=$(pwd)"
        [ -r "${WORKSPACE}/${CONFIG_DIRECTORY}/environments/${ENVIRONMENT}/values.yaml" ] && \
        cp ${WORKSPACE}/${CONFIG_DIRECTORY}/environments/${ENVIRONMENT}/values.yaml tmp/${COMPONENT_NAME}/charts/${ENVIRONMENT}
    fi

    set +e
    chartExists=$(helm list ${COMPONENT_NAME})
    if [ -z $chartExists ]; then
        deleted=$(helm list --all ${COMPONENT_NAME} | grep DELETED)
        echo "DELETED HELM: $deleted"
        if [ ! -z "$deleted" ]; then
            helm delete --purge ${COMPONENT_NAME}
        fi
        set -e
        echo "helm install --name ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true  \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --dry-run"
        helm install --name ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true  \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET} \
        --dry-run
    else
        set -e
        echo "helm upgrade --force ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --install --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN}"
        helm upgrade --force ${COMPONENT_NAME} tmp/${COMPONENT_NAME} --install --namespace ${CLUSTER_NAMESPACE} \
        --set tags.environment=false  --set ${ENVIRONMENT}.enabled=true \
        --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET} \
        --dry-run
    fi

    echo "Remove tmp directory"
    rm -rf tmp
}