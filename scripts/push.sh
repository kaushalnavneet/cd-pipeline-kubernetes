#!/bin/bash

NOCRBUILD=true
if [ "x$1" = x--crbuild ]; then
  shift
  NOCRBUILD=false
fi

RELEASE_NAME=$1
IMAGE_NAME=$1
CHART_DIR=$1
TAG=${2:-latest}
NAMESPACE=opentoolchain
ENVIRONMENT=${3:-development}
CODE_BASE=${4:-nodejs6}
PULL_BUILDER=${5:-true}
CLUSTER_NAME=${6:-otc-us-south-dev}

#export INGRESS_SUBDOMAIN=$(ibmcloud cs cluster-get -s ${CLUSTER_NAME} | grep -i "Ingress subdomain:" | awk '{print $3;}')
#export INGRESS_SECRET=$(ibmcloud cs cluster-get -s ${CLUSTER_NAME} | grep -i "Ingress secret:" | awk '{print $3;}')


cat <<END > build_info.json
{
  "build": "$(date +%Y%m%d%H%M%Z)",
  "commit": "$(git rev-parse HEAD)",
  "appName" : "${RELEASE_NAME}",
  "platform" : "Armada"
}
END

if [  -d cd-pipeline-kubernetes ]; then
  if $NOCRBUILD && hash docker 2>/dev/null; then
    if $PULL_BUILDER ; then
      docker pull registry.ng.bluemix.net/${NAMESPACE}/cd-build-base:${CODE_BASE}
    fi
    docker build -f cd-pipeline-kubernetes/docker/Dockerfile.${CODE_BASE}  --build-arg IDS_USER=${IDS_USER} --build-arg IDS_PASS=${IDS_PASS} -t registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG} . 
    docker push registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG}
  else
    ibmcloud cr build -f cd-pipeline-kubernetes/docker/Dockerfile.${CODE_BASE}   --build-arg IDS_USER=${IDS_USER} --build-arg IDS_PASS=${IDS_PASS}  -t registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG} . 
  fi 
  helm dep up ${CHART_DIR}
  if ! helm list ${RELEASE_NAME}; then
    deleted=$(helm list --all $RELEASE_NAME} | grep DELETED)
    if [ -z $deleted ]; then
      helm delete --purge ${RELEASE_NAME}
    fi
    helm install --name ${RELEASE_NAME} ${CHART_DIR} --namespace ${NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true \
      --set pipeline.image.tag=${TAG} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET} \
      --set pipeline.image.repository=registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME} 
  else
    helm upgrade ${RELEASE_NAME} ${CHART_DIR} --install --namespace ${NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true \
      --set pipeline.image.tag=${TAG} --set global.ingressSubDomain=${INGRESS_SUBDOMAIN} --set global.ingressSecret=${INGRESS_SECRET} \
      --set pipeline.image.repository=registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME} 
  fi
else
  echo "Must clone https://github.ibm.com/org-ids/cd-pipeline-kubernetes as cd-pipeline-kubernetes into root of component directory. Then execute this script as ./cd-pipeline-kubernetes/scripts/push.sh"
fi
