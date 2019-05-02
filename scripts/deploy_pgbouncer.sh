#!/bin/bash
#

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
TARGET=${TARGET:-gitlab}
ENVIRONMENT=${ENVIRONMENT:-development}
DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/pgbouncer_values.yaml
ACCOUNT_ID=${DEPLOY_ACCOUNT_ID:-${ACCOUNT_ID}}
API_KEY=${DEPLOY_API_KEY:-${API_KEY}}


export VAULT_ADDR=https://vserv-eu.sos.ibm.com:8200

# must set base64 encoded VAULT_SIDEKICK_ROLE_ID and VAULT_SIDEKICK_SECRET_ID
export VAULT_TOKEN=$(vault write -field=token auth/approle/login role_id=$( echo $VAULT_SIDEKICK_ROLE_ID | base64 -d - ) \
  secret_id=$( echo $VAULT_SIDEKICK_SECRET_ID | base64 -d - ))

export SECRET_PATH=$( yq -r .global.psql.secretPath ${VALUES} )


export PG_PASSWORD=$( vault read --format=json ${SECRET_PATH} | jq -r .data.DB_PASSWORD )
export PG_USERNAME=admin

ibmcloud login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}
if [[ ! -z "${REGION}" ]]; then
 ibmcloud cs region-set ${REGION}
fi

if [[ ! -z "${RESOURCE_GROUP}" ]]; then
  ibmcloud target -g "${RESOURCE_GROUP}"
fi
$(ibmcloud cs cluster-config --export ${IDS_JOB_NAME})




kubectl -n${CHART_NAMESPACE} delete secret ${TARGET}-postgres-secret
echo "Creating '${TARGET}-postgres-secret' secret..."
kubectl -n${CHART_NAMESPACE} create secret generic ${TARGET}-postgres-secret --from-literal=postgres-password=${PG_PASSWORD}

kubectl -n${CHART_NAMESPACE} delete secret ${TARGET}-pgbouncer-secret
echo "Creating '${TARGET}-pgbouncer-secret' secret..."
cat << EOF > userlist.txt
"${PG_USERNAME}" "md5$(echo -n ${PG_PASSWORD}${PG_USERNAME} | md5sum | cut -d' ' -f1)"
EOF
cat << EOF > .pgpass
*:*:compose:${PG_USERNAME}:${PG_PASSWORD}
EOF
  
kubectl -n${CHART_NAMESPACE} create secret generic ${TARGET}-pgbouncer-secret  --from-file=userlist.txt --from-file=.pgpass
rm -f userlist.txt
rm -f .pgpass


helm init -c
helm dep up

helm upgrade ${TARGET} . \
  --install \
  --set tags.environment=false \
  --set ${ENVIRONMENT}.enabled=true \
  --set enabled=true \
  --namespace ${CHART_NAMESPACE}  \
  --values=${VALUES} \
  --timeout 600 \
  --debug


#helm install --name ${TARGET} . \
#  --set tags.environment=false \
#  --set ${ENVIRONMENT}.enabled=true \
#  --set enabled=true \
#  --namespace ${CHART_NAMESPACE}  \
#  --values=${VALUES} \
#  --timeout 600 \
#  --debug \
#  --dry-run

