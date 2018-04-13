#!/bin/bash


RELEASE_NAME=$1
IMAGE_NAME=$1
CHART_DIR=$1
TAG=${2:-latest}
NAMESPACE=opentoolchain
ENVIRONMENT=${3:-development}
CODE_BASE=${4:-nodejs6}

if [  -d cd-pipeline-kubernetes ]; then
  if hash docker 2>/dev/null; then
    docker build -f cd-pipeline-kubernetes/docker/Dockerfile.${CODE_BASE} -t registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG} . 
    docker push registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG}
  else
    bx cr build -f cd-pipeline-kubernetes/docker/Dockerfile.${CODE_BASE} -t registry.ng.bluemix.net/${NAMESPACE}/${IMAGE_NAME}:${TAG} . 
  fi 
  helm dep up ${RELEASE_NAME}
  if ! helm list ${RELEASE_NAME}; then
    deleted=$(helm list --all $RELEASE_NAME} | grep DELETED)
    if [ -z $deleted ]; then
      helm delete --purge ${RELEASE_NAME}
    fi
    helm install --name ${RELEASE_NAME} ${CHART_DIR} --namespace ${NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${TAG}
  else
    helm upgrade ${RELEASE_NAME} ${CHART_DIR} --install --namespace ${NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --set pipeline.image.tag=${TAG}
  fi
else
  echo "Must clone https://github.ibm.com/org-ids/cd-pipeline-kubernetes as cd-pipeline-kubernetes into root of component directory. Then execute this script as ./cd-pipeline-kubernetes/scripts/push.sh"
fi
