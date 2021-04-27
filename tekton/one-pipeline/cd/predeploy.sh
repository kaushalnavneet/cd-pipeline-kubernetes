#!/usr/bin/env bash
echo ">>>>>>>>>>>>>>>>>>>"
export IDS_TOKEN=$(cat /config/git-token)
cd "${WORKSPACE}"
echo "Cloning Config Repo"
export CONFIG_REPO=$(cat /config/configuration-repo)
export CONFIG_BRANCH=$(cat /config/configuration-branch)
export CONFIG_DIRECTORY=$(cat /config/configuration-directory)
echo $CONFIG_REPO $CONFIG_BRANCH $CONFIG_DIRECTORY

echo "echo -n $IDS_TOKEN" > ./token.sh
chmod +x ./token.sh

GIT_ASKPASS=./token.sh git clone --single-branch --branch "${CONFIG_BRANCH}" "${CONFIG_REPO}" "$CONFIG_DIRECTORY"
echo "Cloning Charts Repo"
export CHARTS_REPO=$(cat /config/charts-repo)
export CHARTS_BRANCH=$(cat /config/charts-branch)
export CHARTS_DIRECTORY=$(cat /config/charts-directory)
echo $CHARTS_REPO $CHARTS_BRANCH $CHARTS_DIRECTORY
GIT_ASKPASS=./token.sh git clone --single-branch --branch "${CHARTS_BRANCH}" "${CHARTS_REPO}" "${CHARTS_DIRECTORY}"

echo "pwd=$(pwd)"
ls -la
echo ">>>>>>>>>>>>>>>>>>>"