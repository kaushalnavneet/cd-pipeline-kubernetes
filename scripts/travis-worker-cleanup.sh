#!/bin/bash
#set -o errexit
set +x
NAMESPACE=opentoolchain

OLDIFS=$IFS

PIPELINE_MON_WEBHOOK=$PIPELINE_MON_WEBHOOK
ALL_REGIONS=${ALL_REGIONS:-syd,tok,lon,wdc,dal}
REGION=${REGION:-us-south}

if [[ -z $PIPELINE_MON_WEBHOOK ]]; then
	echo "PIPELINE_MON_WEBHOOK is not defined"
	exit 1
fi

#if [[ -z $API_KEY ]]; then
#	echo "API_KEY is not defined"
#	exit 1
#fi

# $1=cluster to check
function cleanup_docker_containers () {
	cluster=$1
	# Determine how many travis workers there are
	travis_worker_arr=()
	while IFS='' read -r line; do travis_worker_arr+=("$line"); done < <(kubectl get pods -n "${NAMESPACE}" | grep travis-worker | grep Running | awk '{print $1}')

    echo ${travis_worker_arr[@]}

	errors=false
	# Scan all travis workers for mining jobs and kill them
	for worker in "${travis_worker_arr[@]}"; do
		echo "Checking $worker"
		containers=()
		while IFS='' read -r line; do containers+=("$line"); done < <(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c 'docker ps -aq')
		echo "All containers: ${containers[@]}"
		for container in "${containers[@]}"; do
			echo "Inspecting container $container"
            status=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker inspect $container | jq -r '.[] .State.Status'")
			result=$(echo $?)
			if [[ result == 1 ]]; then
				echo "docker container $container has been terminated"
			else
				echo "status: $status"
				case $status in
					exited)
						echo "Exited container"
						removed=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker rm $container")
						result=$(echo $?)
						if [[ result == 1 ]]; then
							echo "Removing container $container failed"
						else
							echo "Removing container $container was successful"
						fi
						;;
					running)
						echo "Running container"
						current=$(date -u -v-65M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '65 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
						echo "current date - 65m=$current"
						started=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker inspect $container | jq -r '.[] .State.StartedAt'")
						echo "Started: $started"
						if [ "$started" \< "$current" ]; then
							echo "Container started more than one hour ago. Need to stop it and clean it"
							# notify slack channel
							send_to_slack "error" "The container $container is older than 1h and should be clean\nFound in $worker on $cluster"
							errors=true
							#stopped=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker kill $container")
							#result=$(echo $?)
							#if [[ result == 1 ]]; then
							#	echo "Stopping container $container failed"
							#else
							#	echo "Stopping container $container was successful"
							#	removed=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker rm $container")
							#	result=$(echo $?)
							#	if [[ result == 1 ]]; then
							#		echo "Removing container $container failed"
							#		# notify slack channel
							#	else
							#		echo "Removing container $container was successful"
							#	fi
							#fi
						else 
							echo "Container started less than one hour ago -- keep it running"
						fi
						;;
					created)
						echo "Created container"
						current=$(date -u -v-65M +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '65 minutes ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
						echo "current date - 65m =$current"
						started=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker inspect $container | jq -r '.[] .State.StartedAt'")
						echo "Started: $started"
						if [ "$started" \< "$current" ]; then
							echo "Container was created more than one hour ago. Need to stop it and clean it"
							# notify slack channel
							send_to_slack "error" "The container $container is older than 1h and should be clean\nFound in $worker on $cluster"
							errors=true
							#removed=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "docker rm $container")
							#result=$(echo $?)
							#if [[ result == 1 ]]; then
							#	echo "Removing container $container failed"
							#	# notify slack channel
							#else
							#	echo "Removing container $container was successful"
							#fi
						else 
							echo "Container was created less than one hour ago -- leave it as is"
						fi
				esac
			fi
			echo "Done inspecting container $container"
		done
		#check travis-worker service
		check_travis_service=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "service travis-worker status | grep started")
		result=$(echo $?)
		if [[ result == 1 ]]; then
			echo "travis-worker service is not up and running for $worker on $cluster"
			send_to_slack "error" "travis-worker service is not up and running in $worker on $cluster"
			errors=true
		else
			echo "travis-worker service is up and running for $worker on $cluster"
		fi
		#check environment variables
		PID=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "ps -ef  -o user,pid,comm | grep travis-worker | awk '{print \$2}'")
		if [ -z "$PID" ]; then
			all_processes=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "ps -ef")
			echo "$all_processes"
			send_to_slack "error" "The pid for travis-worker process could not be found in $worker on $cluster:\n$all_processes"
			errors=true
		else
			echo "PID=$PID"
			check_payload=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "cat /proc/$PID/environ | grep PAYLOAD_CIPHER_KEY")
			result=$(echo $?)
			if [[ result == 1 ]]; then
				echo "PAYLOAD_CIPHER_KEY is not set for $worker on $cluster"
				# notify slack channel
				send_to_slack "error" "The environment variable PAYLOAD_CIPHER_KEY is not set in $worker on $cluster"
				errors=true
			else
				echo "PAYLOAD_CIPHER_KEY is set for $worker on $cluster"
			fi
			check_rabbit=$(kubectl -n "${NAMESPACE}" -c pipeline exec "$worker" -- sh -c "cat /proc/$PID/environ | grep RABBITMQ_SERVER_URLS")
			result=$(echo $?)
			if [[ result == 1 ]]; then
				echo "RABBITMQ_SERVER_URLS is not set for $worker on $cluster"
				# notify slack channel
				send_to_slack "error" "The environment variable RABBITMQ_SERVER_URLS is not set in $worker on $cluster"
				errors=true
			else
				echo "RABBITMQ_SERVER_URLS is set for $worker on $cluster"
			fi
		fi
	done
	if [ "$errors" = true ]; then
		send_to_slack "error" "Errors were found checking travis-workers on $cluster"
	else 
		send_to_slack "info" "All travis-workers on $cluster have been checked successfully"
	fi
}

# $1 = "info" or "error"
# $2 text message
function send_to_slack() {
	slack_message=$(echo -e "$2")
	case $1 in
		info)
			text_template='{"text":"travis-worker checker", "attachments": [{"title": "travis-worker check is clean","text": "%s", "color": "#19cf19"}]}'
			;;
		error)
			text_template='{"text":"travis-worker checker", "attachments": [{"title": "travis-worker checker found issues","text": "%s", "color": "#c21807"}]}'
			;;
	esac
	json_string=$(printf "$text_template" "$slack_message" )
	curl -X POST -H 'Content-type: application/json' --data "$json_string" $PIPELINE_MON_WEBHOOK
}

# $1 = cluster name
# $2 = webhook
function post_soc_notify() {
	OLDIFS=$IFS
	IFS=','
	read account_name account_guid username < <(
		ibmcloud target --output json | \
	    jq --raw-output '[.account.name, .account.guid, .user.display_name] | join(",")')
	IFS=$OLDIFS
	slack_message=$(echo -e "Executing into:\nCRN App ID: continuous-delivery\nCluster name: $1\nPod: travis-worker-0, travis-worker-1\nUser: $username\nAccount: $account_name ($account_guid)\nJustification: checking travis-workers")
	json_string=$(echo "{\"text\": \"$slack_message\" }")
	echo $json_string
	curl -X POST -H 'Content-type: application/json' --data "$json_string" $2
}

# $1=region (one of lon,dal,tok,wdc,syd)
function check_travis_workers() {
	region=$1
	# list all clusters for region $region
	clusters_to_check=()
	while IFS='' read -r line; do clusters_to_check+=("$line"); done < <(ibmcloud ks clusters | grep otc-pw | grep $region | grep prod | awk '{print $1}')
	for cluster in "${clusters_to_check[@]}"; do
		ibmcloud ks cluster config --cluster $cluster
		echo "check $cluster"
		cleanup_docker_containers $cluster
	done
}

function check_all_clusters() {
	ibmcloud login --apikey $API_KEY -r $REGION
	IFS=',' read -ra regions <<< $(echo $ALL_REGIONS)
	IFS=$OLDIFS
	for region in $regions
	do
		check_travis_workers $region
	done
}

check_all_clusters