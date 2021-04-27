#!/usr/bin/env bash
source "${WORKSPACE}/${ONE_PIPELINE_CONFIG_DIRECTORY_NAME}/tekton/one-pipeline/cd/helpers.sh
echo ">>>>>>>>>>>>>>>>>>>"
env
echo ">>>>>>>>>>>>>>>>>>>"
cd "${WORKSPACE}"
ls -la
echo ">>>>>>>>>>>>>>>>>>>"
ls -la "${WORKSPACE}/$INVENTORY_REPO_DIRECTORY_NAME"
echo ">>>>>>>>>>>>>>>>>>>"
cat "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"
echo ""
jq -rc '.[]' "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"
echo ">>>>>>>>>>>>>>>>>>>"