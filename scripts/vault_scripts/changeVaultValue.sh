#!/bin/bash
# Prior to execution login into an acount that has write, then set the read token VAULT_TOKEN

#eg. generic/project/continuous-delivery-dev/cd-pipeline/development/pipeline-service
CONTEXT=$1
VAULT_KEY=$2
VAULT_VALUE=$3

vault read --format=json ${CONTEXT} | jq '.data' > ${VAULT_KEY}-prev.json
vault read --format=json ${CONTEXT} | jq --arg key ${VAULT_KEY} --arg newval "${VAULT_VALUE}" '.data | .[$key]=$newval' | VAULT_TOKEN= vault write ${CONTEXT} -
