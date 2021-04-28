#!/usr/bin/env bash
echo ">>>>>>>>>>>>>>>>>>>"
env
pwd
echo ">>>>>>>>>>>>>>>>>>>"
IDS_TOKEN=$(cat /config/IDS_TOKEN)
echo "echo -n $IDS_TOKEN" > ./token.sh
chmod +x ./token.sh

echo "Cloning Config Repo"
WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
cd ${WORKSPACE}/${WORK_DIR}
CONFIG_REPO=$(cat /config/CONFIG_REPO)
CONFIG_BRANCH=$(cat /config/CONFIG_BRANCH)
CONFIG_DIRECTORY=$(cat /config/CONFIG_DIRECTORY)
echo $CONFIG_REPO $CONFIG_BRANCH $CONFIG_DIRECTORY
GIT_ASKPASS=./token.sh git clone --single-branch --branch ${CONFIG_BRANCH} ${CONFIG_REPO}   

echo "Cloning Charts Repo"
CHARTS_REPO=$(cat /config/CHARTS_REPO)
CHARTS_BRANCH=$(cat /config/CHARTS_BRANCH)
CHARTS_DIRECTORY=$(cat /config/CHARTS_DIRECTORY)
echo $CHARTS_REPO $CHARTS_BRANCH $CHARTS_DIRECTORY
GIT_ASKPASS=./token.sh git clone --single-branch --branch ${CHARTS_BRANCH} ${CHARTS_REPO}   

echo ">>>>>>>>>>>>>>>>>>>"
ls
cd /workspace/app/one-pipeline-config-repo
echo ">>>>>>>>>>>>>>>>>>>"