#!/bin/bash
#set -o errexit
set +x
NAMESPACE=opentoolchain

OLDIFS=$IFS

ALL_REGIONS=${ALL_REGIONS:-syd,au-syd,tok,lon,wdc,dal,fra}
REGION=${REGION:-us-south}
ALL_DEPLOYMENTS=${ALL_DEPLOYMENTS:-blade-pipeline-broker,otc-github-relay-pub,pipeline-artifact-repository-service,pipeline-event-service,pipeline-log-service,pipeline-service,pipeline-support-service,pipeline-ui,private-worker-service,tekton-pipeline-service}
ALL_STATEFULSETS=${ALL_STATEFULSETS:-pipeline-consumption}

ALL_PW_DEPLOYMENTS=${ALL_PW_DEPLOYMENTS:-cryptomining-detector}
ALL_PW_STATEFULSETS=${ALL_PW_STATEFULSETS:-travis-registry,travis-worker}

# $1=cluster to check
function rollout () {
	cluster=$1
	echo "check $cluster"
	# rollout all pipeline deployment
	echo -n $cluster | grep pw > /dev/null
	if [ $? -ne 0 ]; then
		#normal cluster
		check_deployments_statefulsets $ALL_DEPLOYMENTS $ALL_STATEFULSETS
	else
		#pw cluster
		check_deployments_statefulsets $ALL_PW_DEPLOYMENTS $ALL_PW_STATEFULSETS
	fi
}

function check_deployments_statefulsets() {
	# $1 = deployments
	# $2 = statefulsets
	IFS=',' read -ra deployments <<< $(echo $1)
	IFS=',' read -ra statefulsets <<< $(echo $2)
	IFS=$OLDIFS

	echo "All deployments: ${deployments[@]}"
	echo "All statefulsets: ${statefulsets[@]}"

	for deployment in ${deployments[@]}
	do
		echo "Rolling out $deployment"
		kubectl -n ${NAMESPACE} rollout restart deployment/$deployment
	done
	for statefulset in ${statefulsets[@]}
	do
		echo "Rolling out $statefulset"
		kubectl -n ${NAMESPACE} rollout restart statefulset/$statefulset
	done

	for deployment in ${deployments[@]}
	do
		echo "Rolling out $deployment"
		kubectl -n ${NAMESPACE} rollout status deployment/$deployment -w --timeout=10m
	done
	for statefulset in ${statefulsets[@]}
	do
		echo "checking status for $statefulset"
		kubectl -n ${NAMESPACE} rollout status statefulset/$statefulset -w --timeout=20m
	done
}
# $1=region (one of lon,dal,tok,wdc,syd,au-syd,fra)
function check_pw_clusters() {
	region=$1
	# list all clusters for region $region
	clusters_to_check=()
	while IFS='' read -r line; do clusters_to_check+=("$line"); done < <(ibmcloud ks clusters | grep otc-pw-$region | grep prod | awk '{print $1}')
	echo "All pw clusters: ${clusters_to_check[@]}"
	for cluster in "${clusters_to_check[@]}"; do
		ibmcloud ks cluster config --cluster $cluster
		rollout $cluster
	done
}

# $1=region (one of lon,dal,tok,wdc,syd,au-syd,fra)
function check_clusters() {
	region=$1
	# list all clusters for region $region
	clusters_to_check=()
	while IFS='' read -r line; do clusters_to_check+=("$line"); done < <(ibmcloud ks clusters | grep otc-$region | grep prod | awk '{print $1}')
	echo "All clusters: ${clusters_to_check[@]}"
	for cluster in "${clusters_to_check[@]}"; do
		ibmcloud ks cluster config --cluster $cluster
		rollout $cluster
	done
}

function check_all_clusters() {
	ibmcloud login --apikey $API_KEY -r $REGION
	IFS=',' read -ra regions <<< $(echo $ALL_REGIONS)
	IFS=$OLDIFS
	echo "All regions: ${regions[@]}"
	for region in ${regions[@]}
	do
		# exclude pw clusters for now
		check_pw_clusters $region
		check_clusters $region
	done
}

check_all_clusters