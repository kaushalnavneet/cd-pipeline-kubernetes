#!/bin/bash
#set -o errexit
set +x
NAMESPACE=opentoolchain

OLDIFS=$IFS

ALL_REGIONS=${ALL_REGIONS:-syd,tok,lon,wdc,dal,au-syd}
REGION=${REGION:-us-south}
ALL_DEPLOYMENTS=${ALL_DEPLOYMENTS:-blade-pipeline-broker,otc-github-relay-pub,otc-github-relay-sub,pipeline-artifact-repository-service,pipeline-event-service,pipeline-log-service,pipeline-service,pipeline-support-service,pipeline-ui,private-worker-service}
ALL_STATEFULSETS=${ALL_STATEFULSETS:-pipeline-consumption}

ALL_PW_DEPLOYMENTS=${ALL_PW_DEPLOYMENTS:-cryptomining-detector}
ALL_PW_STATEFULSETS=${ALL_PW_STATEFULSETS:-travis-registry,travis-worker}

# $1=cluster to check
function rollout () {
	cluster=$1
	# rollout all pipeline deployment
	# Determine how many travis workers there are
	if [ echo -n $cluster | grep pw ]; then
		#pw cluster
		IFS=',' read -ra deployments <<< $(echo $ALL_PW_DEPLOYMENTS)
		IFS=',' read -ra statefulsets <<< $(echo $ALL_PW_DEPLOYMENTS)
		IFS=$OLDIFS
	else
		#normal cluster
		IFS=',' read -ra deployments <<< $(echo $ALL_DEPLOYMENTS)
		IFS=',' read -ra deployments <<< $(echo $ALL_STATEFULSETS)
		IFS=$OLDIFS
	fi
	for deployment in $deployments
	do
		echo "Rolling out $deployment"
		#kubectl -n ${NAMESPACE} rollout restart deployment/$deployment
	done
	for statefulset in $statefulsets
	do
		echo "Rolling out $statefulset"
		#kubectl -n ${NAMESPACE} rollout restart statefulset/$statefulset
	done

	for deployment in $deployments
	do
		kubectl -n ${NAMESPACE} rollout status deployment/$deployment -w
	done
	for statefulset in $statefulsets
	do
		kubectl -n ${NAMESPACE} rollout status statefulset/$statefulset -w
	done

}

# $1=region (one of lon,dal,tok,wdc,syd,au-syd,fra)
function check_pw_clusters() {
	region=$1
	# list all clusters for region $region
	clusters_to_check=()
	while IFS='' read -r line; do clusters_to_check+=("$line"); done < <(ibmcloud ks clusters | grep otc-pw-$region | grep prod | awk '{print $1}')
	echo "All clusters: ${clusters_to_check[@]}"
	for cluster in "${clusters_to_check[@]}"; do
		ibmcloud ks cluster config --cluster $cluster
		echo "check $cluster"
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
		echo "check $cluster"
		rollout $cluster
	done
}

function check_all_clusters() {
	ibmcloud login --apikey $API_KEY -r $REGION
	IFS=',' read -ra regions <<< $(echo $ALL_REGIONS)
	IFS=$OLDIFS
	for region in $regions
	do
		check_pw_clusters $region
		check_clusters $region
	done
}

check_all_clusters