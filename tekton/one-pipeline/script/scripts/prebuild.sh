#!/usr/bin/env bash
echo ">>>>>>>>>>>>>>>>>>>"
env | sort
CURRENT_DIR=$(pwd)
echo ">>>>>>>>>>>>>>>>>>>"

WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
cd ${WORKSPACE}/${WORK_DIR}
echo "Current dir: $(pwd)"
echo ">>>>>>>>>>>>>>>>>>>"

IDS_TOKEN=$(cat /config/IDS_TOKEN)
echo "echo -n $IDS_TOKEN" > ./token.sh
chmod +x ./token.sh
ls
echo ">>>>>>>>>>>>>>>>>>>"

echo "Cloning Config Repo"
CONFIG_REPO=$(cat /config/CONFIG_REPO)
CONFIG_BRANCH=$(cat /config/CONFIG_BRANCH)
CONFIG_DIRECTORY=$(cat /config/CONFIG_DIRECTORY)
echo $CONFIG_REPO $CONFIG_BRANCH $CONFIG_DIRECTORY
GIT_ASKPASS=./token.sh git clone --single-branch --branch ${CONFIG_BRANCH} ${CONFIG_REPO} ${CONFIG_DIRECTORY}

echo "Cloning Charts Repo"
CHARTS_REPO=$(cat /config/CHARTS_REPO)
CHARTS_BRANCH=$(cat /config/CHARTS_BRANCH)
CHARTS_DIRECTORY=$(cat /config/CHARTS_DIRECTORY)
echo $CHARTS_REPO $CHARTS_BRANCH $CHARTS_DIRECTORY
GIT_ASKPASS=./token.sh git clone --single-branch --branch ${CHARTS_BRANCH} ${CHARTS_REPO} ${$CHARTS_DIRECTORY}

cd ${CURRENT_DIR}