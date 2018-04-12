#!/bin/bash

IBM_CLOUD_API=${IBM_CLOUD_API:-api.ng.bluemix.net}
IMAGE_NAME=${IMAGE_NAME:-${IMAGE_REGISTRY}/${IMAGE_NAMESPACE}/${IDS_STAGE_NAME}}
COMPONENT_NAME=${COMPONENT_NAME:-${IMAGE_NAME##*/}}
CHART_NAMESPACE=${CHART_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}

cp -a /work cd-pipeline-kubernetes

git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
git config --global user.email "idsorg@us.ibm.com"
git config --global user.name "IDS Organization"
git config --global push.default matching

CHART_VERSION=$(ls -v ${CHART_REPO_ABS}/charts/${COMPONENT_NAME}* 2> /dev/null | sort --version-sort --field-separator=- --key=2,2 | tail -n 1 | grep -Eo '${MAJOR_VERSION}\.${MINOR_VERSION}\.[0-9]+' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")

printf "Publishing chart ${COMPONENT_NAME},\nversion ${CHART_VERSION},\n for cluster ${IDS_JOB_NAME},\nnamespace ${CHART_NAMESPACE},\nwith image: ${IMAGE_NAME}:${APPLICATION_VERSION}\n"

bx login -a ${IBM_CLOUD_API} -c ${ACCOUNT_ID} --apikey ${API_KEY}

$(bx cs cluster-config --export ${IDS_JOB_NAME})

if [ -z "${MAJOR_VERSION}" ] ||  [ -z "${MINOR_VERSION}" ] ||  [ -z "${CHART_ORG}" ] ||  [ -z "${CHART_REPO}" ]; then
  echo "Major & minor version and chart repo vars need to be set"
  exit 1
fi

CHART_REPO_ABS=$(pwd)/${CHART_REPO}

#specific tag
yq --yaml-output '.pipeline.image.tag="${APPLICATION_VERSION}"' ${COMPONENT_NAME}/values.yaml > ${COMPONENT_NAME}/values.yaml
#specific image
yq --yaml-output '.pipeline.image.repository="${IMAGE_NAME}"' ${COMPONENT_NAME}/values.yaml > ${COMPONENT_NAME}/values.yaml

#turn off all enviroments, use umbrella level
yq --yaml-output 'del(.. | select(path(.tags? // empty | .[] | select(test("environment")))))' ${COMPONENT_NAME}/requirements.yaml > ${COMPONENT_NAME}/requirements.yaml

yq --yaml-output '.version="${CHART_VERSION}"' ${COMPONENT_NAME}/Chart.yaml > ${COMPONENT_NAME}/Chart.yaml

helm init -c

git -C $CHART_REPO_ABS pull --no-edit

helm dep up ${COMPONENT_NAME}
echo "=========================================================="
echo "Linting Component Helm Chart"
if helm lint --strict --namespace ${CHART_NAMESPACE} ${COMPONENT_NAME}; then
  echo "helm lint done"
else
  echo "helm lint failed"
  echo "Currently helm linting won't fail the build." 
  #exit 1
fi

echo -e "Dry run into: ${IDS_JOB_NAME}/${CHART_NAMESPACE}."
if helm upgrade ${COMPONENT_NAME} ${COMPONENT_NAME} --namespace ${CHART_NAMESPACE} --install --dry-run; then
  echo "helm upgrade --dry-run done"
else
  echo "helm upgrade --dry-run failed"
  exit 1
fi


echo "Packaging Helm Chart"

mkdir -p $CHART_REPO_ABS/charts
helm package ${IMAGE_NAME} -d $CHART_REPO_ABS/charts

cd $CHART_REPO_ABS
echo "Updating Helm Chart Repository index"
touch charts/index.yaml

if [ "$PRUNE_CHART_REPO" == "true" ]; then
    NUMBER_OF_VERSION_KEPT=${NUMBER_OF_VERSION_KEPT:-3}
    echo "Keeping last ${NUMBER_OF_VERSION_KEPT} versions of ${IMAGE_NAME} component"
    ls -v charts/${IMAGE_NAME}* | head --lines=-${NUMBER_OF_VERSION_KEPT} | xargs rm
fi

helm repo index charts --url https://$IDS_TOKEN@raw.github.ibm.com/$CHART_ORG/$CHART_REPO/master/charts

git add -A .
git commit -m "${IMAGE_NAME} $VERSION"
git push
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

if [ -n "$TRIGGER_BRANCH" ]; then
  echo "Triggering CD pipeline ..."
  mkdir trigger
  cd trigger
  git clone https://$IDS_USER:$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO -b $TRIGGER_BRANCH
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  cd $CHART_REPO
  printf "On $(date), published helm chart for $RELEASE_NAME ($VERSION)" > trigger.txt
  git add .
  git commit -m "Published $RELEASE_NAME ($VERSION)"
  git push
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  echo "CD pipeline triggered"
fi
