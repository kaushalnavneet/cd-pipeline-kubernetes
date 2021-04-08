#!/usr/bin/env bash

#
# prepare data
#

if [ -f "/config/DEV_MODE" ]; then
        export DEV_MODE=$(cat /config/DEV_MODE) 
fi

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

    ibmcloud config --check-version=false
    ibmcloud plugin install -f container-service
    ibmcloud login -a ${API} -r ${REGISTRY_REGION} --apikey ${API_KEY}
    
    IMAGE_URL=${IMAGE_URL:-${REGISTRY_URL}/${REGISTRY_NAMESPACE}/${IMAGE_NAME}}
    COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}

    if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        APPLICATION_VERSION=$( cat /workspace/appVersion )
        if [[  -z "${APPLICATION_VERSION}" || "${APPLICATION_VERSION}" == "latest" ]]; then
        ibmcloud cr images --restrict ${IMAGE_NAMESPACE}/${COMPONENT_NAME} > _allImages
        APPLICATION_VERSION=$(cat _allImages | grep $(cat _allImages | grep latest | awk '{print $3}') | grep -v latest | awk '{print $2}')
        fi
    fi
    git config --global user.email "idsorg@us.ibm.com"
    git config --global user.name "IDS Organization"
    git config --global push.default matching

    CHART_REPO=$( basename $CHART_REPO .git )
    CHART_REPO_ABS=$(pwd)/${CHART_REPO}
    CHART_VERSION=$(ls -v ${CHART_REPO_ABS}/charts/${COMPONENT_NAME}* 2> /dev/null | tail -n -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | awk -F'.' -v OFS='.' '{$3=sprintf("%d",++$3)}7' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")
    CHART_VERSION=${CHART_VERSION:=1.0.0}

    printf "Publishing chart ${COMPONENT_NAME},\nversion ${CHART_VERSION},\n for cluster ${DRY_RUN_CLUSTER},\nnamespace ${CHART_NAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}\n"

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
    yq --yaml-output --arg appver "${APPLICATION_VERSION}" '.pipeline.image.tag=$appver' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

    #specific image
    yq --yaml-output --arg image "${IMAGE_URL}" '.pipeline.image.repository=$image' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

    yq --yaml-output --arg chartver "${CHART_VERSION}" '.version=$chartver' ${COMPONENT_NAME}/Chart.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/Chart.yaml

    helm init -c --stable-repo-url https://charts.helm.sh/stable
    helm dep up ${COMPONENT_NAME}
    echo "=========================================================="
    echo -e "Dry run into: ${DRY_RUN_CLUSTER}/${CHART_NAMESPACE}."
    if helm upgrade ${COMPONENT_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --install --dry-run --debug; then
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
        git -C $CHART_REPO_ABS pull --no-edit
        mkdir -p $CHART_REPO_ABS/charts
        helm package ${COMPONENT_NAME} -d $CHART_REPO_ABS/charts

        cd $CHART_REPO_ABS
        echo "Updating Helm Chart Repository index"
        touch charts/index.yaml

        if [ "$PRUNE_CHART_REPO" == "true" ]; then
        NUMBER_OF_VERSION_KEPT=${NUMBER_OF_VERSION_KEPT:-3}
        echo "Keeping last ${NUMBER_OF_VERSION_KEPT} versions of ${COMPONENT_NAME} component"
        ls -v charts/${COMPONENT_NAME}* | head -n -${NUMBER_OF_VERSION_KEPT} | xargs rm
        fi

        helm repo index charts --url https://$IDS_TOKEN@raw.github.ibm.com/$CHART_ORG/$CHART_REPO/master/charts

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
        git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO $CHART_REPO_ABS
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