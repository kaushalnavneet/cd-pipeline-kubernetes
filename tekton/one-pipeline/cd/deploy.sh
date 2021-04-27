#!/usr/bin/env bash
source "${WORKSPACE}/${ONE_PIPELINE_CONFIG_DIRECTORY_NAME}/tekton/one-pipeline/cd/helpers.sh"
echo ">>>>>>>>>>>>>>>>>>>"
env
echo ">>>>>>>>>>>>>>>>>>>"
cd "${WORKSPACE}"
ls -la
echo ">>>>>>>>>>>>>>>>>>>"
export CLUSTER_NAMESPACE=$(cat /config/cluster-namespace)
export API_KEY=$(cat /config/API_KEY_1416501)
declare -a apps=($(jq -rc '.[]' "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"))

for app in "${apps[@]}"; do
    if [[ "$app" != *"_image" ]]; then
        echo "deploy ${app}"
        deployComponent "${app}" "otc-osa21-prod" "${CLUSTER_NAMESPACE}" "${REGION}" "${REGION}"
    fi
done