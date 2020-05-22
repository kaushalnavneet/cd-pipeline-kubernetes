#!/bin/bash

BEARER=$( ibmcloud iam oauth-tokens --output json | jq -r .iam_token )

# download any logs from the deployment runs
echo Downloading deployment logs...
export TMP_LOGS=/tmp/logs.csv
rm -f $TMP_LOGS
[ -r "$DEPLOYS_FILE" ] && cat "$DEPLOYS_FILE" | cut -f5 -d, | sort -u | while read url ; do
  RUN=$( echo "$url" \
      | cut -f7-9 -d/ | cut -f1 -d\? )
  RUN_ID=$( echo "$RUN" | cut -f3 -d/ )
  echo "Downloading PipelineRun ${RUN_ID}"
  curl -s "https://devops-api.us-south.devops.cloud.ibm.com/v1/tekton-pipelines/${RUN}"   \
          -H  "accept: */*"   -H "Authorization: $BEARER" >/tmp/${RUN_ID}.json

  jq '.resources[] | select ( .kind == "TaskRun" ) | select ( .metadata.labels["tekton.dev/task"] == "deploy-chart" ) ' /tmp/${RUN_ID}.json >/tmp/t1.json


  jq -r '.spec.params[] | select ( .name == "clusterName" ).value' /tmp/t1.json \
  |  grep -v none | while read cluster; do
    echo Examining $cluster
    jq '. | select ( any(.spec.params[] ; .value == "'$cluster'" ) ) ' /tmp/t1.json >/tmp/t2.json
    COMPONENT=$( jq -r '.spec.params[] | select ( .name == "imageUrl" ).value' /tmp/t2.json | cut -f3 -d/ )
    LOG_ID=$( jq '.metadata.annotations["devops.cloud.ibm.com/tekton-logs"]' /tmp/t2.json | jq '. | fromjson ' | jq -r '.[]'  )
    echo Processing ${COMPONENT}:${cluster}. Downloading log ${LOG_ID}
    curl -s "https://devops-api.us-south.devops.cloud.ibm.com/v1/tekton-pipelines/${RUN}/${LOG_ID}/logs"   \
        -H  "accept: */*"   -H "Authorization: $BEARER" >/tmp/${RUN_ID}-${COMPONENT}-${cluster}.log
    echo "$COMPONENT,$cluster,${RUN_ID},${RUN_ID}-${COMPONENT}-${cluster}.log" >>$TMP_LOGS
  done
done

# create log CTASKS
[ -r "$TMP_LOGS" ] && cat "$TMP_LOGS" | while read csv_line ; do
  COMPONENT=$( echo "$csv_line" | cut -f1 -d, )
  CLUSTER=$( echo "$csv_line" | cut -f2 -d, )
  RUN_ID=$( echo "$csv_line" | cut -f3 -d, )
  FILE=$( echo "$csv_line" | cut -f4 -d, )
  printf "Creating CTASK for PipelineRun ${RUN_ID}\nComponent: $COMPONENT\nCluster: $CLUSTER\nEnvironment: $ENVIRONMENT\n"

  SUMMARY=$( cat /tmp/"$FILE" |  python -c 'import json,sys; print(json.dumps(sys.stdin.read()))' ) # could use jq here
  cat - >"$TMP" <<HERE
{
  "required": "required",
  "system": "$SYSTEM",
  "shortdescription": "$COMPONENT:$CLUSTER logs",
  "description": "Deploy Logs for PipelineRun ${RUN_ID}\nComponent: $COMPONENT\nCluster: $CLUSTER\nEnvironment: $ENVIRONMENT",
  "data": $SUMMARY
}
HERE
  RESPONSE=$(curl --request POST -H "Authorization:Bearer $SN_TOKEN" \
      -H "updated_by: $ASSIGNED_TO" \
      -H "Accept:application/json" \
      -H "Content-Type:application/json" \
      --data "@$TMP" "$SN_URL/api/ibmwc/v2/change/$CR_ID/task/create" \
      --silent --show-error)

  CTASK_ID=$(jq --raw-output ".result.number | select (.!=null)" <<< "$RESPONSE")

  if [[ ! "$CTASK_ID" ]]; then
      echo "Failed: $RESPONSE"
      exit 1
  fi
  echo "Created CTASK $CTASK_ID. Closing..."
  PAYLOAD=$(jq --null-input "$(cat <<HERE
{
    state: "Closed"
}
HERE
  )")

  RESPONSE=$(curl --request PUT -H "Authorization:Bearer $SN_TOKEN" \
      -H "updated_by: $ASSIGNED_TO" \
      -H "Accept:application/json" \
      -H "Content-Type:application/json" \
      --data "$PAYLOAD" "$SN_URL/api/ibmwc/v2/change/$CR_ID/task/$CTASK_ID/update" \
      --silent --show-error)

  CTASK_ID=$(jq --raw-output ".result.number | select (.!=null)" <<< "$RESPONSE")

  if [[ ! "$CTASK_ID" ]]; then
      echo "Failed: $RESPONSE"
      exit 1
  fi
done
