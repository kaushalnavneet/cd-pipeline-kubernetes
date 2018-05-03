#!/bin/bash
# Prior to execution login into an acount that has write, then set the read token VAULT_TOKEN

TIAM_SECRET=$1
CONTEXT=${2:-generic/project/continuous-delivery-stage/cd-pipeline/staging}
VAULT_TOKEN_SAVE=$VAULT_TOKEN

vault read --format=json ${CONTEXT}/blade-pipeline-broker | jq --arg newval ${TIAM_SECRET} '.data | .vcap_pipeline_secret=$newval | .TIAM_CLIENT_SECRET=$newval' | VAULT_TOKEN= vault write ${CONTEXT}/blade-pipeline-broker -
vault read --format=json ${CONTEXT}/pipeline-service | jq --arg newval ${TIAM_SECRET} '.data | .vcap_pipeline_secret=$newval' | VAULT_TOKEN= vault write ${CONTEXT}/pipeline-service  -
vault read --format=json ${CONTEXT}/pipeline-ui | jq --arg newval ${TIAM_SECRET} '.data | .vcap_pipeline_secret=$newval | .TIAM_CLIENT_SECRET=$newval' | VAULT_TOKEN= vault write ${CONTEXT}/pipeline-ui -

