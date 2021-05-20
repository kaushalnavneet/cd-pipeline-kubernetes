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

if [ -f "/config/RUN_PII" ]; then
    export RUN_PII=$(cat /config/RUN_PII)
else
    export RUN_PII=false
fi
if [ "$RUN_PII" == true ]; then
    echo "Cloning pii Repo"
    GIT_ASKPASS=./token.sh git clone --depth 1 "https://github.ibm.com/org-ids/pii"
    REPO_URL=$(git config --get remote.origin.url | sed -E "s/^.*(@|\/\/)([^:\/]+)(\/|:)(.+)$/https:\/\/\2\/\4/" | sed -E "s/^(.*)\.git$/\1/")
    REPO_NAME=${REPO_URL##*/}
    echo "${REPO_NAME}"
    pii/run
    rm -rf pii
else
    echo "Skip pii scan"
fi