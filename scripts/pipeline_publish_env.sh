#!/bin/bash

CHART_NAMESPACE=${CHART_NAMESPACE:-${IMAGE_NAMESPACE}}
ENVIRONMENT=${ENVIRONMENT:-development}
WORKDIR=${WORKDIR:-/work}

if [ -z "${MAJOR_VERSION}" ] ||  [ -z "${MINOR_VERSION}" ] ||  [ -z "${CHART_ORG}" ] ||  [ -z "${CHART_REPO}" ]; then
  echo "Major & minor version and chart repo vars need to be set"
  exit 1
fi

git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO
rc=$?; echo "error is $rc"; if [[ $rc != 0 ]]; then exit $rc; fi
git config --global user.email "idsorg@us.ibm.com"
git config --global user.name "IDS Organization"
git config --global push.default matching

ENVIRONMENT_REPO_ABS=$(pwd)/${CHART_REPO}

ENVIRONMENT_VERSION=$(ls -v ${ENVIRONMENT_REPO_ABS}/charts/${ENVIRONMENT}* 2> /dev/null | tail -n -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | awk -F'.' -v OFS='.' '{$3=sprintf("%d",++$3)}7' || echo "${MAJOR_VERSION}.${MINOR_VERSION}.0")
ENVIRONMENT_VERSION=${ENVIRONMENT_VERSION:=1.0.0}

printf "Publishing environment ${ENVIRONMENT},\nversion ${ENVIRONMENT_VERSION}\n"

tmp=$(mktemp)
yq --yaml-output --arg envver "${ENVIRONMENT_VERSION}" '.version=$envver' ${WORKDIR}/environments/${ENVIRONMENT}/Chart.yaml > "$tmp" && mv "$tmp" ${WORKDIR}/environments/${ENVIRONMENT}/Chart.yaml 

#Construct the environment fragment to be included in the umbrella
components=$(yq -r --arg env ${ENVIRONMENT} '.[$env] | to_entries[] | .key | select( . as $in | ["probes", "basedomain","vault","configmap", "resources"] | index($in) | not )' ${WORKDIR}/environments/${ENVIRONMENT}/values.yaml)
first=true
for component in $components
do
  if [ "$first" = false ] ; then
    REQUIREMENTS=${REQUIREMENTS}","
  else
    first=false
  fi
  REQUIREMENTS=${REQUIREMENTS}$(jq -n --arg env "${ENVIRONMENT}" --arg component "$component" '{"child":"\($env)","parent":"\($component).pipeline"}')
  REQUIREMENTS=${REQUIREMENTS}","$(jq -n --arg env "${ENVIRONMENT}" --arg component "$component" '{"child":"\($env).\($component)","parent":"\($component).pipeline"}')
done

helm init -c
# Add the repository that contains the individual components packaged helm charts (if needed)
if helm repo add otc-config --no-update https://$IDS_TOKEN@raw.github.ibm.com/$CHART_ORG/$CHART_REPO/master/charts; then
  echo "Helm repo otc-config added"
else
  echo "Helm repo otc-config already present"
fi

echo "=========================================================="
echo "Linting Environment Chart"
if helm lint --strict --namespace ${CHART_NAMESPACE} ${WORKDIR}/environments/${ENVIRONMENT}; then
  echo "helm lint done"
else
  echo "helm lint failed"
  exit 1
fi

git -C $ENVIRONMENT_REPO_ABS pull --no-edit

echo "Packaging Environment Chart"

# Enironmement fragment
echo '{ "dependencies": [ {"name":"'${ENVIRONMENT}'","version":"'${ENVIRONMENT_VERSION}'","repository":"alias:otc-config","tags":["environment"],"import-values":['${REQUIREMENTS}']}]}' | yq --yaml-output '.' > ${ENVIRONMENT_REPO_ABS}/charts/requirements.${ENVIRONMENT}.yaml
sed -i '2,$s/^/  /'  ${ENVIRONMENT_REPO_ABS}/charts/requirements.${ENVIRONMENT}.yaml

mkdir -p $ENVIRONMENT_REPO_ABS/charts
helm package ${WORKDIR}/environments/${ENVIRONMENT} -d $ENVIRONMENT_REPO_ABS/charts

cd $ENVIRONMENT_REPO_ABS
echo "Updating Environment Chart Repository index"
touch charts/index.yaml

if [ "$PRUNE_ENVIRONMENT_REPO" == "true" ]; then
    NUMBER_OF_VERSION_KEPT=${NUMBER_OF_VERSION_KEPT:-3}
    echo "Keeping last ${NUMBER_OF_VERSION_KEPT} versions of ${ENVIRONMENT}"
    ls -v charts/${ENVIRONMENT}* | head --lines=-${NUMBER_OF_VERSION_KEPT} | xargs rm
fi

helm repo index charts --url https://$IDS_TOKEN@raw.github.ibm.com/$CHART_ORG/$CHART_REPO/master/charts

git add -A .
git commit -m "${ENVIRONMENT} ${ENVIRONENT_VERSION}"
git push
rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi

if [ -n "$TRIGGER_BRANCH" ]; then
  echo "Triggering CD pipeline ..."
  mkdir trigger
  cd trigger
  git clone https://$IDS_TOKEN@github.ibm.com/$CHART_ORG/$CHART_REPO -b $TRIGGER_BRANCH
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  cd $ENVIRONMENT_REPO_ABS
  printf "On $(date), published helm chart for $ENVIRONMENT ($ENVIRONMENT_VERSION)" > trigger.txt
  git add .
  git commit -m "Published $ENVIRONMENT ($ENVIRONMENT_VERSION)"
  git push
  rc=$?; if [[ $rc != 0 ]]; then exit $rc; fi
  echo "CD pipeline triggered"
fi
