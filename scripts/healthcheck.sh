#!/bin/bash
set -eou pipefail

OLDIFS=$IFS
MAX_DURATION=7200

hasNotReadyPods() {
    local result=$1
    local namespace=$2
    local prefix=$3

    issuesForPods=$(kubectl -n $namespace get pods -ojson | jq --arg prefix "$prefix" '.items[]? | select(.metadata.name | startswith($prefix)) |  .status.conditions[]? |  select(.status == "False") | .reason')
    if [ "$issuesForPods" ]; then
        eval "$result=true"
    else
        eval "$result=false"
    fi
}

waitForReadyPods() {
    local namespace=$1
    local prefix=$2
    if [ -z "$prefix" ]; then
        prefix=""
    fi

    echo "Check pods for $2 in namespace $1"
    local notReadyPods
    hasNotReadyPods notReadyPods $namespace $prefix
    local loopTimes=20
    while [ "$notReadyPods" == "true" ] && [ $loopTimes -ne 0 ]; do
        echo "Not all $prefix pods are ready in $namespace"
        local pods
        pods=$(kubectl get pod -n $namespace)
        if [ "$prefix" != "" ]; then
            pods=$( echo "$pods" | grep $prefix )
        fi
        # Filter out pods that indicate that all containers are running (up to 5)
        echo "$pods" | grep -v '1/1\|2/2\|3/3\|4/4\|5/5' || true # grep will exit 1 if no match, so ensure the command is successful with || true
        echo
        echo "Checking back in 30s"
        echo
        sleep 30
        ((loopTimes=loopTimes-1))
        hasNotReadyPods notReadyPods $namespace $prefix
    done
    if [ $loopTimes -eq 0 ]; then
        hasNotReadyPods notReadyPods $namespace $prefix
        if [ "$notReadyPods" == "true" ]; then
            echo "Could not get all pods for $prefix in $namespace ready in 10 minutes"
            return 1
        fi
    fi
    echo "All $prefix pods are ready in $namespace"
}

hasNotDeployedTodayPods() {
    local result=$1
    local namespace=$2
    local prefix=$3

    local now=$(date --utc +%s)
    IFS=$OLDIFS
    startingTimes=$(kubectl -n $namespace get pods -ojson | jq -r --arg prefix "$prefix" '.items[]? | select(.metadata.name | startswith($prefix)) |  .status.startTime')
    for time in $startingTimes
    do
        start=$(date --date $time +%s)
        diff=$((now - start))
        if [ "$diff" -gt "$MAX_DURATION" ]; then
            # pod was started more than 2 hours ago
            eval "$result=true"
            return
        fi
    done
    eval "$result=false"
}

namespace=$1
componentsFileName=$2

if [ ! -f $componentsFileName ]; then
    echo "Missing components.txt file. Aborting"
    exit 1
fi

NOT_OK="false"
IFS=','
apps=$(cat $componentsFileName)
for app in $apps
do
    if [ $app == "travis-worker-go" ]; then
        echo "Skip travis-worker-go"
    else
        waitForReadyPods $namespace $app
        if [ $? == 0 ]; then
            # pods are ready - checking it was deployed by checking the starting time
            hasNotDeployedTodayPods notDeployedToday $namespace $app
            if [ "$notDeployedToday" == "true" ]; then
                NOT_OK="true"
                echo "$app in $namespace has not been deployed today"
            fi
        fi
    fi
done

if [ $NOT_OK == "true" ]; then
    echo "Some apps have not been deployed today"
    exit 1
fi
echo "All deployed apps have been successfully checked"