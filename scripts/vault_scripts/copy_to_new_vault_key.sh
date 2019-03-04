#!/bin/bash
# Script copies all contents from location OLD_CONTEXT into NEW_CONTEXT and makes a local backup copy of the values in OLD_CONTEXT
#
#  ex: ./modify_vault.sh generic/project/continuous-delivery-dev/cd-pipeline/development/travis-worker/travis-worker_2019_03_04_14h06m41s
OLD_CONTEXT=${1}
NAME=$( echo ${OLD_CONTEXT} | rev | cut -d'/' -f2 | rev  )
NEW_CONTEXT="$( echo ${OLD_CONTEXT} | rev | cut -d'/' -f2- | rev )/${NAME}_$(date -u +%Y_%m_%d_%Hh%Mm%Ss)"

echo "==="
echo ${OLD_CONTEXT}
BACKUP_NAME=$(echo ${OLD_CONTEXT} | rev | cut -d'/' -f-2 | rev | sed 's/\//_/g')

vault read --format=json ${OLD_CONTEXT} | jq '.data' > ${BACKUP_NAME}-$(date -u +%Y_%m_%d_%Hh%Mm%Ss)-prev.json
vault read --format=json ${OLD_CONTEXT} | jq '.data' | VAULT_TOKEN= vault write ${NEW_CONTEXT} -
echo "==="
 