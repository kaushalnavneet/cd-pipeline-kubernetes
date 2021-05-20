#!/bin/bash
set -eou pipefail

namespace=$1
componentsFileName=$2

if [ ! -f $componentsFileName ]; then
    echo "Missing components.txt file. Aborting"
    exit 1
fi

IFS=','
apps=$(cat $componentsFileName)
for app in $apps
do
    if [ $app == "travis-worker-go" ]; then
        echo "Skip travis-worker-go"
    elif [ $app == "cryptomining-detector" ]; then
        echo "Skip cryptomining-detector"
    elif [ $app == "pipeline-consumption" ]; then
        if ! kubectl -n $namespace rollout status statefulset/$app -w --timeout=10m; then
            echo "$app in $namespace didn't restart properly"
        fi
    else
        if ! kubectl -n $namespace rollout status deplopyment/$app -w --timeout=10m; then
            echo "$app in $namespace didn't restart properly"
        fi
    fi
done

echo "All pods for deployed apps have been successfully restarted"