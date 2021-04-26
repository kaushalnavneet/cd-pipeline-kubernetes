#!/usr/bin/env bash
echo "setup"

# config
export ENVIRONMENT=$(get_env region)
export INVENTORY_URL=https://github.ibm.com/org-ids/cd-pipeline-ci-inventory
export INVENTORY_BRANCH=$(get_env target-environment)
export IDS_JOB_ID=$PIPELINE_RUN_ID
export IDS_USER=idsorg
export PRUNE_CHART_REPO="true"
export NAMESPACE=opentoolchain
export DRY_RUN=$(get_env DRY_RUN "")
export DEPLOYMENT_SLACK_CHANNEL_ID=$(get_env DEPLOYMENT_SLACK_CHANNEL_ID)

# secrets
export IDS_TOKEN=$(get_env git-token)
export IC_1308775_API_KEY=$(get_env IC_1308775_API_KEY "")
export IC_1651315_API_KEY=$(get_env IC_1651315_API_KEY "")
export IC_1416501_API_KEY=$(get_env IC_1416501_API_KEY "")
export IC_1561947_API_KEY=$(get_env IC_1561947_API_KEY "")
export IC_1562047_API_KEY=$(get_env IC_1562047_API_KEY "")
export IC_2113612_API_KEY=$(get_env IC_2113612_API_KEY "")
export NR_1783376_API_KEY=$(get_env NR_1783376_API_KEY)
export OTC_REGISTRY_API_KEY=$(get_env IC_1416501_API_KEY "")
export DEPLOYMENT_SLACK_TOKEN=$(get_env DEPLOYMENT_SLACK_TOKEN)

if [ "${SKIP}" == true ]; then
    echo "Skipping Deploy for $CLUSTER_NAME"
    exit 0
fi
ls -la