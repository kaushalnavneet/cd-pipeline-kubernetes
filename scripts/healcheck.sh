#!/bin/bash
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
    local loopTimes = 2
    while [ "$notReadyPods" == "true" && loopTimes != 0 ]; do
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
        loppTimes--
        hasNotReadyPods notReadyPods $namespace $prefix
    done
    echo "All $prefix pods are ready in $namespace"
    echo
}

local componentsFileName=$1
local namespace=$2

if [ -f $componentsFileName]; then
    echo "Missing componments.txt file. Aborting"
    exit 1
fi

IFS=','
apps=$(cat $componentsFileName)
for app in $apps
do
    if [ $app == "travis-worker-go" ]; then
        echo "Skip travis-worker-go"
    else
        waitForReadyPods $namespace $app
    fi
done
 echo "All deployed apps have been successfully checked"