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
DRY_RUN_CLUSTER=${DRY_RUN_CLUSTER:-${IDS_JOB_NAME}}
WORKDIR=${WORKDIR:-/work}
ACCOUNT_ID=${DRY_RUN_ACCOUNT_ID:-${ACCOUNT_ID}}
API_KEY=${DRY_RUN_API_KEY:-${API_KEY}}

cp -a ${WORKDIR} cd-pipeline-kubernetes
mv cd-pipeline-kubernetes/devops-config .

git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
git config --global user.email "idsorg@us.ibm.com"
git config --global user.name "IDS Organization"
git config --global push.default matching

CHART_REPO_ABS=$(pwd)/${CHART_REPO}
CHART_VERSION=$(ls -v ${CHART_REPO_ABS}/charts/${COMPONENT_NAME}* 2> /dev/null | tail -n -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | awk -F'.' -v OFS='.' '{$3=sprintf("%d",++$3)}7' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")
CHART_VERSION=${CHART_VERSION:=1.0.0}

printf "Publishing chart ${COMPONENT_NAME},\nversion ${CHART_VERSION},\n for cluster ${DRY_RUN_CLUSTER},\nnamespace ${CHART_NAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}\n"

ibmcloud login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(ibmcloud ks cluster config --export --cluster ${DRY_RUN_CLUSTER})

if [ -z "${MAJOR_VERSION}" ] ||  [ -z "${MINOR_VERSION}" ] ||  [ -z "${CHART_ORG}" ] ||  [ -z "${CHART_REPO}" ]; then
  echo "Major & minor version and chart repo vars need to be set"
  exit 1
fi


#specific tag
tmp=$(mktemp)
yq --yaml-output --arg appver "${APPLICATION_VERSION}" '.pipeline.image.tag=$appver' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

#specific image
yq --yaml-output --arg image "${IMAGE_NAME}" '.pipeline.image.repository=$image' ${COMPONENT_NAME}/values.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/values.yaml

yq --yaml-output --arg chartver "${CHART_VERSION}" '.version=$chartver' ${COMPONENT_NAME}/Chart.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/Chart.yaml

helm init -c
helm dep up ${COMPONENT_NAME}
echo "=========================================================="
echo -e "Dry run into: ${DRY_RUN_CLUSTER}/${CHART_NAMESPACE}."
if helm upgrade ${COMPONENT_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --set tags.environment=false --set ${ENVIRONMENT}.enabled=true --install --dry-run; then
  echo "helm upgrade --dry-run done"
else
  echo "helm upgrade --dry-run failed"
  exit 1
fi

echo "Packaging Helm Chart"

#turn off local enviroments, use umbrella published environment
rm -fr ${COMPONENT_NAME}/requirements.lock ${COMPONENT_NAME}/charts
yq --yaml-output 'del(.. | select(path(.tags? // empty | .[] | select(test("environment")))))' ${COMPONENT_NAME}/requirements.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/requirements.yaml

# Move common dependency to unqiue name

yq --yaml-output --arg chartver "${COMPONENT_NAME}-common" '.name=$chartver' cd-pipeline-kubernetes/helm/pipeline-deployment/Chart.yaml > "$tmp" && mv "$tmp" cd-pipeline-kubernetes/helm/pipeline-deployment/Chart.yaml

mv cd-pipeline-kubernetes/helm/pipeline-deployment cd-pipeline-kubernetes/helm/${COMPONENT_NAME}-common

yq --yaml-output --arg chartver "file://../cd-pipeline-kubernetes/helm/${COMPONENT_NAME}-common" '(.dependencies[] | select(.name=="pipeline-deployment") | .repository ) |= $chartver' ${COMPONENT_NAME}/requirements.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/requirements.yaml 
yq --yaml-output '(.dependencies[] | select(.name=="pipeline-deployment") | .alias ) |= "pipeline"' ${COMPONENT_NAME}/requirements.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/requirements.yaml 
yq --yaml-output --arg chartver "${COMPONENT_NAME}-common" '(.dependencies[] | select(.name=="pipeline-deployment") | .name ) |= $chartver' ${COMPONENT_NAME}/requirements.yaml > "$tmp" && mv "$tmp" ${COMPONENT_NAME}/requirements.yaml 

helm dep up ${COMPONENT_NAME}

n=0
rc=0
ORIG_DIR=$(pwd)
until [ $n -ge 5 ]
do
  git -C $CHART_REPO_ABS pull --no-edit
  mkdir -p $CHART_REPO_ABS/charts
  helm package ${COMPONENT_NAME} -d $CHART_REPO_ABS/charts

  cd $CHART_REPO_ABS
  echo "Updating Helm Chart Repository index"
  touch charts/index.yaml

  if [ "$PRUNE_CHART_REPO" == "true" ]; then
    NUMBER_OF_VERSION_KEPT=${NUMBER_OF_VERSION_KEPT:-3}
    echo "Keeping last ${NUMBER_OF_VERSION_KEPT} versions of ${COMPONENT_NAME} component"
    ls -v charts/${COMPONENT_NAME}* | head -n -${NUMBER_OF_VERSION_KEPT} | xargs rm
  fi

  helm repo index charts --url https://$IDS_TOKEN@raw.github.ibm.com/$CHART_ORG/$CHART_REPO/master/charts

  git add -A .
  git commit -m "${APPLICATION_VERSION}"
  git push
  rc=$?
  if [[ $rc == 0 ]]; then 
    break;
  fi
  n=$[$n+1]
  cd $ORIG_DIR
  rm -fr $CHART_REPO_ABS
  mkdir -p $CHART_REPO_ABS
  git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO $CHART_REPO_ABS
done

if [[ $rc != 0 ]]; then exit $rc; fi

if [ -n "$TRIGGER_BRANCH" ]; then
  echo "Triggering CD pipeline ..."
  mkdir trigger
  cd trigger
  git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO -b $TRIGGER_BRANCH
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  cd $CHART_REPO_ABS 
  printf "On $(date), published helm chart for $COMPONENT_NAME ($CHART_VERSION)" > trigger.txt
  git add .
  git commit -m "Published $COMPONENT_NAME ($CHART_VERSION)"
  git push
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  echo "CD pipeline triggered"
fi
