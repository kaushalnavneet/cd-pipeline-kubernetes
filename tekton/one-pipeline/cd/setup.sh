#!/usr/bin/env bash
echo "setup"

# config
export ENVIRONMENT=$(get_env region)
export INVENTORY_URL=https://github.ibm.com/org-ids/cd-pipeline-ci-inventory
export INVENTORY_BRANCH=$(get_env target-environment)
export IDS_JOB_ID=$PIPELINE_RUN_ID
export IDS_USER=idsorg
export NAMESPACE=opentoolchain
#export DEPLOYMENT_SLACK_CHANNEL_ID=$(get_env DEPLOYMENT_SLACK_CHANNEL_ID)

# secrets
export IDS_TOKEN=$(get_env git-token)
