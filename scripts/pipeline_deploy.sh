#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017, 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
IBM_CLOUD_API=${IBM_CLOUD_API:-cloud.ibm.com}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
CHART_NAMESPACE=${CHART_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}
REGION=${REGION}
WORKDIR=${WORKDIR:-/work}
ACCOUNT_ID=${DEPLOY_ACCOUNT_ID:-${ACCOUNT_ID}}
API_KEY=${DEPLOY_API_KEY:-${API_KEY}}

printf "Deploying release ${IDS_STAGE_NAME} into cluster ${IDS_JOB_NAME},\nnamespace ${CHART_NAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}.\n"

cp -a ${WORKDIR} cd-pipeline-kubernetes
mv cd-pipeline-kubernetes/devops-config .


if [[ ! -z "${REGION}" ]]; then
 ibmcloud login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY} -r ${REGION}
else
 ibmcloud login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}
fi

if [[ ! -z "${RESOURCE_GROUP}" ]]; then
  ibmcloud target -g "${RESOURCE_GROUP}"
fi

ksversion=$(ibmcloud plugin list | grep kubernetes | awk '{print $2}' | head -c1)
if [ "$ksversion" -eq "0"  ]; then
    $(ibmcloud ks cluster config --export --cluster ${IDS_JOB_NAME})
else
    ibmcloud ks cluster config --cluster ${IDS_JOB_NAME}
fi

INGRESS_SUBDOMAIN=$(ibmcloud ks cluster get -s --cluster ${IDS_JOB_NAME} | grep -i "Ingress subdomain:" | awk '{print $3;}')
echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
if [[ ${INGRESS_SUBDOMAIN} == *,* ]];then
	INGRESS_SUBDOMAIN=$(echo "$INGRESS_SUBDOMAIN" | cut -d',' -f1)
	echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
fi

INGRESS_SECRET=$(ibmcloud ks cluster get -s --cluster ${IDS_JOB_NAME} | grep -i "Ingress secret:" | awk '{print $3;}')
if [[ ${INGRESS_SECRET} == *,* ]];then
	INGRESS_SECRET=$(echo "$INGRESS_SECRET" | cut -d',' -f1)
	echo "INGRESS SECRET: $INGRESS_SECRET"
fi

tmp=$(mktemp)
yq --yaml-output --arg stagename "${IDS_STAGE_NAME}" '. | .pipeline.fullnameOverride=$stagename | .pipeline.nameOverride=$stagename' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

helm dep up ${COMPONENT_NAME}
if ! helm list ${IDS_STAGE_NAME}; then
  deleted=$(helm list --all ${IDS_STAGE_NAME} | grep DELETED)
  echo "DELETED HELM: $deleted"
  if [ -z $deleted ]; then
    helm delete --purge ${IDS_STAGE_NAME}
  fi
  helm install --name ${IDS_STAGE_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_NAME} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
else
  helm upgrade --force ${IDS_STAGE_NAME} ${COMPONENT_NAME} --install --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_NAME} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
fi
