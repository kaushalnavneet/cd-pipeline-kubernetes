#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
TARGET=${TARGET:-gitlab}
ENVIRONMENT=${ENVIRONMENT:-development}
DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/pgbouncer_values.yaml
API_KEY=${DEPLOY_API_KEY:-${API_KEY}}

set -x
# install vault
curl -o v.zip https://releases.hashicorp.com/vault/1.1.1/vault_1.1.1_linux_amd64.zip
unzip v.zip
rm v.zip

export VAULT_ADDR=https://vserv-eu.sos.ibm.com:8200

# must set base64 encoded VAULT_SIDEKICK_ROLE_ID and VAULT_SIDEKICK_SECRET_ID
export VAULT_TOKEN=$(./vault write -field=token auth/approle/login role_id=$( echo $VAULT_SIDEKICK_ROLE_ID | base64 -d - ) \
  secret_id=$( echo $VAULT_SIDEKICK_SECRET_ID | base64 -d - ))


# for yq 2.2.1
#export SECRET_PATH=$( yq r "${VALUES}" global.psql.secretPath  )

# for yq 2.7.2
export SECRET_PATH=$( yq -r .global.psql.secretPath ${VALUES} )

export PG_PASSWORD=$( ./vault read --format=json ${SECRET_PATH} | jq -r .data.DB_PASSWORD )
export PG_USERNAME=admin

ksversion=$(ibmcloud plugin list | grep kubernetes | awk '{print $2}' | head -c1)
if [ "$ksversion" -eq "0"  ]; then
    $(ibmcloud ks cluster config --export --cluster ${CLUSTER_NAME})
else
    ibmcloud ks cluster config --cluster ${CLUSTER_NAME}
fi

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

helm upgrade ${TARGET} ./charts/pgbouncer  \
  --install \
  --set tags.environment=false \
  --set ${ENVIRONMENT}.enabled=true \
  --set enabled=true \
  --namespace ${CHART_NAMESPACE}  \
  --values=${VALUES} \
  --timeout 600 \
  --debug