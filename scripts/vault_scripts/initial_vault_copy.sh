#!/bin/bash
#
# Given a common path, this script copies all of the values of keys in the path into a new path. It also backs up the current values locally.

COMMON_PATH=${1} #generic/project/continuous-delivery-dev/cd-pipeline/development
TAG=${2:-$(date +%Y%m%d)}

KEYS=`vault list ${COMMON_PATH} | sort | uniq`

for name in ${KEYS}
do
  if [[ $name != "----" && $name != "Keys" ]]; then
  	 CURRENT_CONTEXT=${COMMON_PATH}/${name}
  	 NEW_CONTEXT=${COMMON_PATH}/${name}/${TAG}
  	 echo "==="
  	 echo ${CURRENT_CONTEXT}
     BACKUP_NAME=`echo ${CURRENT_CONTEXT} | rev | cut -d'/' -f-2 | rev | sed 's/\//_/g'`
     vault read --format=json ${CURRENT_CONTEXT} | jq '.data' > ${BACKUP_NAME}-$(date +%Y%m%d)-prev.json
 	 vault read --format=json ${CURRENT_CONTEXT} | jq '.data' | VAULT_TOKEN= vault write ${NEW_CONTEXT} -
     echo "==="
  fi
done