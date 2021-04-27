#!/usr/bin/env bash
echo "deploy"
env
cd "${WORKSPACE}"
ls -la
jq -rc '.[]' "${WORKSPACE}/${DEPLOYMENT_DELTA_PATH}"