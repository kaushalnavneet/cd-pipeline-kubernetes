#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017, 2019. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
IBM_CLOUD_API=${IBM_CLOUD_API:-cloud.ibm.com}
IMAGE_URL=${IMAGE_URL:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IMAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_URL##*/}}
CLUSTER_NAMESPACE=${CLUSTER_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}
REGION=${REGION}
WORKDIR=${WORKDIR:-/work}
API_KEY=${DEPLOY_API_KEY:-${API_KEY}}

printf "Deploying release ${COMPONENT_NAME} into cluster ${CLUSTER_NAME},\nnamespace ${CLUSTER_NAMESPACE},\nwith image: ${IMAGE_URL}:${APPLICATION_VERSION}.\n"

cp -a ${WORKDIR} cd-pipeline-kubernetes
mv cd-pipeline-kubernetes/devops-config .

ibmcloud login -a ${IBM_CLOUD_API} -r ${ACCOUNT_REGION} --apikey ${API_KEY}
if [[ ! -z "${REGION}" ]]; then
 ibmcloud cs region-set ${REGION}
fi

if [[ ! -z "${RESOURCE_GROUP}" ]]; then
  ibmcloud target -g "${RESOURCE_GROUP}"
fi

$(ibmcloud cs cluster-config --export ${CLUSTER_NAME})

INGRESS_SUBDOMAIN=$(ibmcloud cs cluster-get -s ${CLUSTER_NAME} | grep -i "Ingress subdomain:" | awk '{print $3;}')
echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
if [[ ${INGRESS_SUBDOMAIN} == *,* ]];then
	INGRESS_SUBDOMAIN=$(echo "$INGRESS_SUBDOMAIN" | cut -d',' -f1)
	echo "INGRESS SUB DOMAIN: $INGRESS_SUBDOMAIN"
fi

INGRESS_SECRET=$(ibmcloud cs cluster-get -s ${CLUSTER_NAME} | grep -i "Ingress secret:" | awk '{print $3;}')
if [[ ${INGRESS_SECRET} == *,* ]];then
	INGRESS_SECRET=$(echo "$INGRESS_SECRET" | cut -d',' -f1)
	echo "INGRESS SECRET: $INGRESS_SECRET"
fi

tmp=$(mktemp)
yq --yaml-output --arg stagename "${COMPONENT_NAME}" '. | .pipeline.fullnameOverride=$stagename | .pipeline.nameOverride=$stagename' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

helm dep up ${COMPONENT_NAME}
if ! helm list ${COMPONENT_NAME}; then
  deleted=$(helm list --all ${COMPONENT_NAME} | grep DELETED)
  echo "DELETED HELM: $deleted"
  if [ -z $deleted ]; then
    helm delete --purge ${COMPONENT_NAME}
  fi
  helm install --name ${COMPONENT_NAME} ${COMPONENT_NAME} --namespace ${CLUSTER_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_URL} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
else
  helm upgrade --force ${COMPONENT_NAME} ${COMPONENT_NAME} --install --namespace ${CLUSTER_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${APPLICATION_VERSION} --set pipeline.image.repository=${IMAGE_URL} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET}
fi
