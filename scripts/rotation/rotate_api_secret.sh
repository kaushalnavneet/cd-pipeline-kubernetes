#!/bin/bash

export VAULT_ADDR=https://vserv-eu.sos.ibm.com:8200
unset VAULT_TOKEN
ALL_APPS=blade-pipeline-broker,pipeline-artifact-repository-service,pipeline-service,pipeline-ui,private-worker-service,pipeline-event-service,pipeline-support-service
OLDIFS=$IFS

function generate_new_secret() {
    local new_value=$(base64 </dev/urandom | tr -d '/+' | head -c 50)
    echo ${new_value}
}

function generate_new_broker_value() {
    # 1 - temporary file that contains the vault entry contents
    # 2 - new secret
    local new_value=$2
    local old_value=$(cat $1 | jq -r .BROKER_SECRET)
    local previous_value=$(cat $1 | jq 'has("PREVIOUS_BROKER_SECRET")')
    if [ ${previous_value} == "false" ]; then
        local new_content=$(cat $1 | jq --arg BROKER_SECRET $new_value '. + {BROKER_SECRET: $BROKER_SECRET}' | jq --arg PREVIOUS_BROKER_SECRET $old_value '. + {PREVIOUS_BROKER_SECRET: $PREVIOUS_BROKER_SECRET}')
        echo $new_content | jq . > $1
    fi
}

function generate_new_shared_value() {
    # 1 - temporary file that contains the vault entry contents
    # 2 - new secret
    local new_value=$2
    local old_value=$(cat $1 | jq -r .PIPELINE_BASIC_AUTH_TOKEN)
    local previous_value=$(cat $1 | jq 'has("PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN")')
    if [ ${previous_value} == "false" ]; then
        local new_content=$(cat $1 | jq --arg PIPELINE_BASIC_AUTH_TOKEN $new_value '. + {PIPELINE_BASIC_AUTH_TOKEN: $PIPELINE_BASIC_AUTH_TOKEN}' | jq --arg PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN $old_value '. + {PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN: $PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN}')
        echo $new_content | jq . > $1
    fi
}

function generate_new_devx_value() {
    # 1 - temporary file that contains the vault entry contents
    # 2 - new secret
    local new_value=$2
    local old_value=$(cat $1 | jq -r .DEVX_BASIC_AUTH_TOKEN)
    local previous_value=$(cat $1 | jq 'has("PREVIOUS_DEVX_BASIC_AUTH_TOKEN")')
    if [ ${previous_value} == "false" ]; then
        local new_content=$(cat $1 | jq --arg DEVX_BASIC_AUTH_TOKEN $new_value '. + {DEVX_BASIC_AUTH_TOKEN: $DEVX_BASIC_AUTH_TOKEN}' | jq --arg PREVIOUS_DEVX_BASIC_AUTH_TOKEN $old_value '. + {PREVIOUS_DEVX_BASIC_AUTH_TOKEN: $PREVIOUS_DEVX_BASIC_AUTH_TOKEN}')
        echo $new_content | jq . > $1
    fi
}

function get_current_secret() {
    # 1 - temporary file that contains the vault entry contents
    local old_value=$(cat $1 | jq -r .BROKER_SECRET)
    echo ${old_value}
}

function remove_previous() {
    # 1 - temporary file that contains the vault entry contents
    local newresult=$(cat $1 | jq 'del(.PREVIOUS_BROKER_SECRET)' | jq .)
    echo $newresult > $1
}

function remove_previous_pipeline_common() {
    # 1 - temporary file that contains the vault entry contents
    local newresult=$(cat $1 | jq 'del(.PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN)' | jq .)
    echo $newresult > $1
}

function revert_vault_broker_secret() {
    # 1 - vault path
    export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    local vault_contents=$(vault read --format=json "$1" | jq .data)
    local previous_value=$(echo ${vault_contents} | jq 'has("PREVIOUS_BROKER_SECRET")')
    if [ ${previous_value} == "true" ]; then
        local revert_value=$(echo ${vault_contents} | jq -r .PREVIOUS_BROKER_SECRET)
        local tempfile=$(mktemp)
        local reverted_contents=$(echo $vault_contents | jq 'del(.PREVIOUS_BROKER_SECRET)' | jq --arg BROKER_SECRET $revert_value '. + {BROKER_SECRET: $BROKER_SECRET}')
        echo ${reverted_contents} >${tempfile}
        updating_vault ${tempfile} $1
    fi
}

function revert_vault_shared_secret() {
    # 1 - vault path
    export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    local vault_contents=$(vault read --format=json "$1" | jq .data)
    local previous_value=$(echo ${vault_contents} | jq 'has("PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN")')
    if [ ${previous_value} == "true" ]; then
        local revert_value=$(echo ${vault_contents} | jq -r .PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN)
        local tempfile=$(mktemp)
        local reverted_contents=$(echo $vault_contents | jq 'del(.PREVIOUS_PIPELINE_BASIC_AUTH_TOKEN)' | jq --arg PIPELINE_BASIC_AUTH_TOKEN $revert_value '. + {PIPELINE_BASIC_AUTH_TOKEN: $PIPELINE_BASIC_AUTH_TOKEN}')
        echo ${reverted_contents} >${tempfile}
        updating_vault ${tempfile} $1
    fi
}

function revert_vault_pipeline_support_service_secret() {
    # 1 - vault path
    export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    local vault_contents=$(vault read --format=json "$1" | jq .data)
    local previous_value=$(echo ${vault_contents} | jq 'has("PREVIOUS_DEVX_BASIC_AUTH_TOKEN")')
    if [ ${previous_value} == "true" ]; then
        local revert_value=$(echo ${vault_contents} | jq -r .PREVIOUS_DEVX_BASIC_AUTH_TOKEN)
        local tempfile=$(mktemp)
        local reverted_contents=$(echo $vault_contents | jq 'del(.PREVIOUS_DEVX_BASIC_AUTH_TOKEN)' | jq --arg DEVX_BASIC_AUTH_TOKEN $revert_value '. + {DEVX_BASIC_AUTH_TOKEN: $DEVX_BASIC_AUTH_TOKEN}')
        echo ${reverted_contents} >${tempfile}
        updating_vault ${tempfile} $1
    fi
}

function get_vault_path() {
    # 1 - the value.yaml file path
    # 2 - vault path
    # 3 - filter
    local vault_path=$2.vault.secretPaths
    local path=$(yq r $1 $2 | tr '\0' '\n' | grep $3 | cut -d ' ' -f2)
    echo $path
}

function read_vault_path() {
    # 1 - vault entry to read
    # 2 - temp file
    export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    local vault_contents=$(vault read --format=json "$1" | jq .data)
    echo $vault_contents > $2
}

function save_backup() {
    # 1 - new json file to write to vault
    # 2 - vault entry to write
    unset VAULT_TOKEN
    VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    cat "$1" | vault write "$2_$(date -u +%Y_%m_%d_%Hh%Mm%Ss)" -
}
function updating_vault() {
    # 1 - new json file to write to vault
    # 2 - vault entry to write
    unset VAULT_TOKEN
    VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=${ROLE_ID} secret_id=${SECRET_ID})
    vault login ${VAULT_TOKEN} > /dev/null 2>&1
    cat "$1" | vault write "$2" -
}

function update_broker() {
    # 1 - region to update
    # 2 - new secret value
    # 3 - blade broker vault path
    local pipeline_url="https://cloud.ibm.com/devops/pipelines/tekton/api/v1/5c6a4378-f804-435b-af8c-a72eba741a86/runs?env_id=ibm:yp:us-south"
    local environment=$1
    local new_password=$2
    local broker_vault_path=$3
    local password=$(echo $new_password | cut -c 1-7)
    echo "Update broker with ${password} and ${broker_vault_path}"
    local service_ids="pipeline,private_worker"
    case "$1" in
            dev)
                local trigger_name="Update broker in dev"
                ;;
            development)
                local trigger_name="Update broker in dev"
                ;;
            *)
                local trigger_name="Update broker in prod"
    esac

    local bearer_token=$(ic iam oauth-tokens --output json | jq -r .iam_token)
    echo "Invoke \"${trigger_name}\" trigger"
    case "$1" in
            dev)
            echo "Run otc-api pipeline for dev"
    local result=$(curl -s  --silent --location --request POST ${pipeline_url} -H "Content-Type: application/json" -H "Authorization: ${bearer_token}" \
--data-raw "$(cat << EOF
{
    "triggerName": "${trigger_name}",
    "eventParams": {
        "properties": [
            {
                "name": "service-ids",
                "type": "TEXT",
                "value": "${service_ids}"
            },
            {
                "name": "new-auth-password",
                "type": "SECURE",
                "value": "${new_password}"
            }
        ]
    }
}
EOF
)")
                ;;
            developement)
            echo "Run otc-api pipeline for development"
    local result=$(curl -s  --silent --location --request POST ${pipeline_url} -H "Content-Type: application/json" -H "Authorization: ${bearer_token}" \
--data-raw "$(cat << EOF
{
    "triggerName": "${trigger_name}",
    "eventParams": {
        "properties": [
            {
                "name": "service-ids",
                "type": "TEXT",
                "value": "${service_ids}"
            },
            {
                "name": "new-auth-password",
                "type": "SECURE",
                "value": "${new_password}"
            }
        ]
    }
}
EOF
)")
                ;;
            *)
            echo "Run otc-api pipeline for prod"
    local result=$(curl -s  --silent --location --request POST ${pipeline_url} -H "Content-Type: application/json" -H "Authorization: ${bearer_token}" \
--data-raw "$(cat << EOF
{
    "triggerName": "${trigger_name}",
    "eventParams": {
        "properties": [
            {
                "name": "service-ids",
                "type": "TEXT",
                "value": "${service_ids}"
            },
            {
                "name": "environment",
                "type": "TEXT",
                "value": "${environment}"
            },
            {
                "name": "new-auth-password",
                "type": "SECURE",
                "value": "${new_password}"
            }
        ]
    }
}
EOF
)")
    esac
    local result_pipeline=$(echo $result | jq -r .url)
    #echo ${result_pipeline}
    local status="running"

   while [[ ${status} == "running" || ${status} == "queued" || ${status} == "pending" ]];
   do
        sleep 10
        bearer_token=$(ic iam oauth-tokens --output json | jq -r .iam_token)
        wait_for_result=$(curl --silent --location --request GET ${result_pipeline} -H "Authorization: ${bearer_token}" -H 'Content-Type: application/json')
        #echo "result: ${wait_for_result}"
        status=$(echo ${wait_for_result} | jq -r .status.state)
        echo "status found: ${status}"
    done
    if [[ ${status} != "succeeded" ]]; then
        # revert vault contents to previous
        echo "otc-api update for broker pipeline failed for $1"
        echo "revert vault changes for ${broker_vault_path}"
        revert_vault_broker_secret ${broker_vault_path}
        exit 1
    fi
    echo "pipeline broker was successfully updated in otc-api for $1"
}

function restart_pods() {
    # 1 - namespace
    # restart all pods for blade-pipeline-broker,pipeline-artifact-repository-service,pipeline-service,pipeline-ui,private-worker-service,pipeline-event-service,pipeline-support-service
    IFS=',' read -ra deployments <<< $ALL_APPS
	IFS=$OLDIFS

    echo "restart pods"
    for deployment in "${deployments[@]}"; do
        echo "rollout restart for $deployment"
        kubectl -n $1 rollout restart deployment/$deployment
    done

    for deployment in "${deployments[@]}"; do
        kubectl -n $1 rollout status deployment/$deployment -w
    done    
    echo "restart pods done"
}

function cluster_config() {
    # 1 - cluster name
    for iteration in {1..30}
    do
        echo "Running cluster config for cluster $1: $iteration / 30"
        ibmcloud ks cluster config --cluster $1 > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            return 0
        else
            echo "Cluster config for $1 failed. Trying again..."
            sleep 5
        fi
    done
    return 1
}