#!/bin/bash

CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
ENVIRONMENT=${ENVIRONMENT:-dev}
DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/cryptomining_values.yaml
COMPONENT_NAME=cryptomining-detector

# install yq 
YQ2_VERSION=2.4.1
wget --quiet -O yq2_linux_amd64 https://github.com/mikefarah/yq/releases/download/${YQ2_VERSION}/yq_linux_amd64 \
    && mv yq2_linux_amd64 /usr/bin/yq2 \
    && chmod +x /usr/bin/yq2 \
    && ln -fs /usr/bin/yq2 /usr/bin/yq

# update of the cluster name for the current deployment
yq w -i ${VALUES} clusterName ${CLUSTER_NAME}

helm delete --purge cryptomining-detector
kubectl -n opentoolchain delete deployment cryptomining-detector

helm upgrade cryptomining-detector helm/cryptomining-detector \
  --install \
  --namespace "${CHART_NAMESPACE}" \
  --values=${VALUES} \
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
    | jq -r '.spec.template.spec.containers[] | select(.name == "cryptomining-detector").image' \
    | cut -f2 -d: )
  echo "${COMPONENT_NAME},${APP_VERSION},${APP_VERSION},${CLUSTER_NAME},${PIPELINE_RUN_URL}"
  echo "${COMPONENT_NAME},${APP_VERSION},${APP_VERSION},${CLUSTER_NAME},${PIPELINE_RUN_URL}" >>"cr/$ENVIRONMENT/${RUN_ID}.csv"

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
