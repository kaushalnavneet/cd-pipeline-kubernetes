#!/bin/bash
#

set -e

export ENVIRONMENT="$1" ; shift
export REGION="$ENVIRONMENT"
export CLUSTERS="$@"
export POSTGRES_CLUSTER="$1"

DEVOPS_CONFIG=${DEVOPS_CONFIG:-devops-config}
VALUES=${DEVOPS_CONFIG}/environments/${ENVIRONMENT}/pgbouncer_values.yaml
CHART_NAMESPACE=${CHART_NAMESPACE:-opentoolchain}
fecho () {
	echo "$2"
}

if [ ! -z "$DEVOPS_CONFIG_BRANCH" ]; then
	OPTS=" -b $DEVOPS_CONFIG_BRANCH"
fi

if [ ! -e ${DEVOPS_CONFIG} ]; then
	git clone $OPTS git@github.ibm.com:ids-env/devops-config
else
	pushd ${DEVOPS_CONFIG}
	git pull
	popd
fi

export SECRET_PATH=$( yq -r .global.psql.secretPath ${VALUES} )


bx cs region-set "$REGION"

# first, disable amqp in all of the clusters

for CLUSTER_NAME in $CLUSTERS; do
	$( bx cs cluster-config --export "$CLUSTER_NAME" )
	kubectl get configmap -n$CHART_NAMESPACE pipeline-log-service -oyaml >${CLUSTER_NAME}-cm-pipeline-log-service.yaml
	kubectl get deployment -n$CHART_NAMESPACE pipeline-log-service -oyaml >${CLUSTER_NAME}-deployment-pipeline-log-service.yaml

	# pause amqp on all pods in the cluster

	PLS_PODS=$( kubectl get pods -n$CHART_NAMESPACE | grep pipeline-log-service | cut -f1 -d' ' )
	PLS_HOST=$( fecho $( kubectl get ingress -n$CHART_NAMESPACE  | grep pipeline-log-service | cut -f1 -d, ) )
	XAUTH=6c39ac10f8e4831467e062935bb40075.13e968b40e383672f0ef75e4d98787ff4e60ab5e4592eb76a5955aa376a584e8a18f7a3fefa88de8de98fbbceae9308a620802d349f45f1e76d562600e51c6a674beba430bc17db6907e90d753a8a055.88c2d8704a779ba71143d74da5d8ff0cd2d98884
	for pod in $PLS_PODS ; do
		finished=false
		echo "checking $pod in $CLUSTER_NAME"
		while [ $finished == false ]; do
			curl -s -XPUT \
				-H "X-Auth-Token: $XAUTH" \
				https://$PLS_HOST/api/amqp
			kubectl logs -n$CHART_NAMESPACE $pod | grep "Shut down AMQP connection" >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				finished=true
			fi
			# temporary
			#finished=true
		done
		echo $pod AMQP shut down
	done

done

# create the postgresql pod

cat - >postgresql.yaml <<EOF
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: postgres
  namespace: opentoolchain
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:9.6
          imagePullPolicy: "IfNotPresent"
          ports:
            - containerPort: 5432
EOF

cat - >get.psql <<EOF
\copy ( SELECT * FROM log_record WHERE archived = false AND created_at > 1557100800 AND finalized_at IS NULL ) TO 'log_record.csv';
\copy ( SELECT * FROM log_chunk ) TO 'log_chunk.csv';
\q
EOF

cat - >put.psql <<EOF
DROP TABLE log_chunk;
DROP TABLE log_record;
CREATE TABLE IF NOT EXISTS log_record ( 
  log_id VARCHAR(36) NOT NULL, 
  created_at BIGINT NOT NULL, 
  finalized_at BIGINT, 
  aggregated_at BIGINT, 
  archived_at BIGINT, 
  purged_at BIGINT, 
  archiving BOOLEAN DEFAULT false NOT NULL, 
  archived BOOLEAN DEFAULT false NOT NULL, 
  content TEXT, 
  PRIMARY KEY (log_id));
CREATE TABLE IF NOT EXISTS log_chunk ( 
  log_id VARCHAR(36) NOT NULL, 
  log_seq BIGINT NOT NULL, 
  is_final BOOLEAN, 
  content TEXT,
  inserted_at BIGINT NOT NULL,
  PRIMARY KEY (log_id, log_seq));
\copy log_record FROM 'log_record.csv';
\copy log_chunk FROM 'log_chunk.csv'; 
\q
EOF

# do the postgresql transfer from compose to ICD

CLUSTER_NAME=$POSTGRES_CLUSTER
$( bx cs cluster-config --export "$CLUSTER_NAME" )
kubectl apply -f postgresql.yaml
# wait for pod to be ready
while kubectl get pods -n$CHART_NAMESPACE | grep postgres | grep -v 1/1 >/dev/null 2>&1; do
	sleep 5
done
POSTGRES_POD=$( kubectl get pods -n$CHART_NAMESPACE | grep postgres | cut -f1 -d' ' )
kubectl cp icd_env.txt $CHART_NAMESPACE/$POSTGRES_POD:.
kubectl cp compose_env.txt $CHART_NAMESPACE/$POSTGRES_POD:.
kubectl cp get.psql $CHART_NAMESPACE/$POSTGRES_POD:.
kubectl cp put.psql $CHART_NAMESPACE/$POSTGRES_POD:.
echo Running $POSTGRES_POD in $CLUSTER_NAME
echo copying out compose
kubectl exec -n$CHART_NAMESPACE -ti $POSTGRES_POD -- bash -c 'source compose_env.txt ; rm -f log_record.csv log_chunk.csv ; time psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <get.psql'
echo uploading to ICD
kubectl exec -n$CHART_NAMESPACE -ti $POSTGRES_POD -- bash -c 'source icd_env.txt ; time psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <put.psql'



# now actually switch the clusters over to ICD
#

for CLUSTER_NAME in $CLUSTERS; do
	$( bx cs cluster-config --export "$CLUSTER_NAME" )
	cat ${CLUSTER_NAME}-cm-pipeline-log-service.yaml \
		| sed -e 's!DB_HOST: .*$!DB_HOST: gitlab-pgbouncer!g' -e 's!TLSv1.2!""!g' -e 's!DB_PORT: .*$!DB_PORT: "6432"!g' \
		| yq 'del(.metadata.labels)' \
		| yq 'del(.metadata.resourceVersion)' \
		| yq 'del(.metadata.uid)' \
		| yq 'del(.metadata.creationTimestamp)' >${CLUSTER_NAME}-cm-pipeline-log-service-new.yaml
	kubectl apply -f ${CLUSTER_NAME}-cm-pipeline-log-service-new.yaml

	cat ${CLUSTER_NAME}-deployment-pipeline-log-service.yaml \
		| sed -e 's!generic/crn/v1/bluemix/public/continuous-delivery/'$ENVIRONMENT'/cd-pipeline/pipeline-log-service.*$!'${SECRET_PATH}':fmt=json!g' \
		| yq 'del(.metadata.labels)' \
		| yq 'del(.metadata.resourceVersion)' \
		| yq 'del(.metadata.uid)' \
		| yq 'del(.metadata.creationTimestamp)' \
		| yq 'del(.status)' \
		| yq 'del(.metadata.generation)' \
		| yq 'del(.metadata.annotations)' \
		| yq 'del(.spec.selector)' \
		| yq 'del(.spec.template.metadata.labels)' >${CLUSTER_NAME}-deployment-pipeline-log-service-new.yaml
	kubectl apply -f ${CLUSTER_NAME}-deployment-pipeline-log-service-new.yaml

	echo "Applied new configmap and deployment to $CLUSTER_NAME"
	# check to see how restarting pods are doing
	sleep 5
	PLS_PODS=$( kubectl get pods -n$CHART_NAMESPACE | grep pipeline-log-service | grep 0/1 | cut -f1 -d' ' )
	kubectl get pods -n$CHART_NAMESPACE | grep pipeline-log-service
	for pod in $PLS_PODS ; do
		while kubectl get pods -n$CHART_NAMESPACE | grep $pod | grep 0/1 >/dev/null 2>&1; do
			sleep 5
		done
		echo Waiting for $pod container to come up
		sleep 20
		echo ''
		echo "pod $pod is alive in cluster $CLUSTER_NAME"
		kubectl logs $pod
	done
done

