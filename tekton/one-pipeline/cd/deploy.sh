#!/usr/bin/env bash
echo ">>>>>>>>>>>>>>>>>>>"
env
echo ">>>>>>>>>>>>>>>>>>>"
cd "${WORKSPACE}"
ls -la
echo ">>>>>>>>>>>>>>>>>>>"
ls -la "${WORKSPACE}/$INVENTORY_REPO_DIRECTORY_NAME"
echo ">>>>>>>>>>>>>>>>>>>"
cat "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"
jq -rc '.[]' "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"
echo ">>>>>>>>>>>>>>>>>>>"