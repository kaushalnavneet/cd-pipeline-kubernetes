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
COMPONENT_NAME=gitlab-pgbouncer

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
helm repo add gitlab https://charts.gitlab.io/
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

if [ ${CR_DIRECTORY} == "" ]; then
  echo "No CR directory specified"
  exit 0
fi

cd ${CR_DIRECTORY}
if [ -d cr/$ENVIRONMENT ]; then
  # save information for CR
  echo "Saving deploy info for CR"
  RUN=$( echo "${PIPELINE_RUN_URL}" \
        | cut -f7-9 -d/ | cut -f1 -d\? )
  RUN_ID=$( echo "$RUN" | cut -f3 -d/ )
  APP_VERSION=$( kubectl get -n${CHART_NAMESPACE} deployment ${COMPONENT_NAME} -ojson \
    | jq -r '.spec.template.spec.containers[] | select(.name == "pgbouncer").image' \
    | cut -f2 -d: )
  echo "${COMPONENT_NAME},${APP_VERSION},${APPLICATION_VERSION},${CLUSTER_NAME},${PIPELINE_RUN_URL}"
  echo "${COMPONENT_NAME},${APP_VERSION},${APPLICATION_VERSION},${CLUSTER_NAME},${PIPELINE_RUN_URL}" >>"cr/$ENVIRONMENT/${RUN_ID}.csv"

  git config --global user.email "idsorg@us.ibm.com"
  git config --global user.name "IDS Organization"
  git config --global push.default matching
  git add -A "cr/$ENVIRONMENT"
  git commit -m "Adding deploy info for ${COMPONENT_NAME}-${CLUSTER_NAME}"

  n=0
  rc=0
  ORIG_DIR=$(pwd)
  until [ $n -ge 5 ]
  do
    git push
    rc=$?
    if [[ $rc == 0 ]]; then 
      break;
    fi
    n=$[$n+1]
    git pull
  done
else
  echo "cr/$ENVIRONMENT directory doesn't exist"
fi
