#!/bin/bash
# Script copies all contents from location OLD_CONTEXT into NEW_CONTEXT and makes a local backup copy of the values in OLD_CONTEXT
#
#  ex: ./modify_vault.sh generic/project/continuous-delivery-dev/cd-pipeline/development/travis-worker/20181122 generic/project/continuous-delivery-dev/cd-pipeline/development/travis-worker/20181127
OLD_CONTEXT=${1}
NEW_CONTEXT=${2}
echo "==="
echo ${OLD_CONTEXT}
BACKUP_NAME=`echo ${OLD_CONTEXT} | rev | cut -d'/' -f-2 | rev | sed 's/\//_/g'`

vault read --format=json ${OLD_CONTEXT} | jq '.data' > ${BACKUP_NAME}-$(date -u +%Y_%m_%d_%Hh%Mm%Ss)-prev.json
vault read --format=json ${OLD_CONTEXT} | jq '.data' | VAULT_TOKEN= vault write ${NEW_CONTEXT} -
echo "==="
 