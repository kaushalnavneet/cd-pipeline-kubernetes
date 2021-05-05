#!/usr/bin/env bash
# need helm 2.14.3
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --version v2.14.3

source "${WORKSPACE}/${ONE_PIPELINE_CONFIG_DIRECTORY_NAME}/tekton/one-pipeline/cd/helpers.sh"
export CLUSTER_NAMESPACE=$(cat /config/cluster-namespace)

export API_KEY=$(cat /config/ibmcloud-api-key)
declare -a apps=($(jq -rc '.[]' "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"))

for app in "${apps[@]}"; do
    if [[ "$app" != *"_image" ]]; then
        echo "deploy ${app}"
        export CLUSTER_NAME1=$(cat /config/cluster_name1)
        export CLUSTER_NAME2=$(cat /config/cluster_name2)
        export CLUSTER_NAME3=$(cat /config/cluster_name3)
        if [[ "$app" == "travis-worker" ]]; then
            export CLUSTER_NAME1="$(echo $CLUSTER_NAME1 | cut -d - -f1)-pw-$(echo $CLUSTER_NAME1 | cut -d - -f2-3)"
            export CLUSTER_NAME2="$(echo $CLUSTER_NAME2 | cut -d - -f1)-pw-$(echo $CLUSTER_NAME2 | cut -d - -f2-3)"
            export CLUSTER_NAME3="$(echo $CLUSTER_NAME3 | cut -d - -f1)-pw-$(echo $CLUSTER_NAME3 | cut -d - -f2-3)"
        fi
        deployComponent "${app}" "${CLUSTER_NAME1}" "${CLUSTER_NAMESPACE}" "${REGION}"
        deployComponent "${app}" "${CLUSTER_NAME2}" "${CLUSTER_NAMESPACE}" "${REGION}"
        deployComponent "${app}" "${CLUSTER_NAME3}" "${CLUSTER_NAMESPACE}" "${REGION}"
    fi
done