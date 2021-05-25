#!/usr/bin/env bash
set -eo pipefail
echo ">>>>>>>>>>>>>>>>>>>"
env | sort
CURRENT_DIR=$(pwd)
echo ">>>>>>>>>>>>>>>>>>>"

if [ -f "/config/SOURCE_DIRECTORY" ]; then 
    WORK_DIR=$(cat /config/SOURCE_DIRECTORY)
    cd ${WORKSPACE}/${WORK_DIR}
    echo "Current dir: $(pwd)"

    echo ">>>>>>>>>>>>>>>>>>>"

    if [ -f "/config/IDS_TOKEN" ]; then 
        IDS_TOKEN=$(cat /config/IDS_TOKEN)
        if [ -z "$IDS_TOKEN" ]; then
            echo "IDS_TOKEN is missing"
            exit 1
        fi

        if [ -f "/config/RUN_PII" ]; then
            export RUN_PII=$(cat /config/RUN_PII)
        else
            export RUN_PII=false
        fi
        if [ "$RUN_PII" == true ]; then
            echo "Cloning pii Repo"
            git clone --depth 1 "https://${IDS_TOKEN}@github.ibm.com/org-ids/pii"
            pii/run
            rm -rf pii
        else
            echo "Skip pii scan"
        fi
    fi
fi