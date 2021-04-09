#!/bin/bash
NODE_VERSION=2.18.2
NAMESPACE="opentoolchain"
OLDIFS=$IFS
RED='\033[0;31m'
NC='\033[0m' # No Color

checkNodeVersion() {
    local namespace=$1
    local prefix=$2

	pods=()
	while IFS='' read -r line; do pods+=("$line"); done < <(kubectl get pods -n "${namespace}" | grep $prefix | grep Running  | awk '{print $1}')

    echo "Checking ${pods[0]}"
    status=$(kubectl -n "${namespace}" exec ${pods[0]} -- node --version | grep $NODE_VERSION)
    if [[ -z $status ]]; then
        echo -e "${RED}Wrong node version for ${pods[0]}${NC}"
    fi
}

IFS=','
apps="blade-pipeline-broker,otc-github-relay-pub,pipeline-artifact-repository-service,pipeline-consumption,pipeline-event-service,pipeline-log-service,pipeline-ui,private-worker-service,pipeline-support-service,tekton-pipeline-service"
#apps="pipeline-support-service"

for app in $apps
do
    checkNodeVersion $NAMESPACE $app
done