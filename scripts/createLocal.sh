#!/bin/bash
#

sed \
 -e "s!@KREDIS_PORT@!$KREDIS_PORT!g" \
 -e "s!@KREDIS_HOST@!$KREDIS_HOST!g" \
 -e "s!@KREDIS_PASSWORD@!$KREDIS_PASSWORD!g" \
 -e "s!@KPG_PORT@!$KPG_PORT!g" \
 -e "s!@KPG_HOST@!$KPG_HOST!g" \
 -e "s!@KPG_USERID@!$KPG_USERID!g" \
 -e "s!@KPG_PASSWORD@!$KPG_PASSWORD!g" \
 -e "s!@KAMQP_PORT@!$KAMQP_PORT!g" \
 -e "s!@KAMQP_HOST@!$KAMQP_HOST!g" \
 -e "s!@KAMQP_USERID@!$KAMQP_USERID!g" \
 -e "s!@KAMQP_PASSWORD@!$KAMQP_PASSWORD!g" \
 -e "s!@KCOUCHDB_HOST@!$KCOUCHDB_HOST!g" \
 -e "s!@KCOUCHDB_PORT@!$KCOUCHDB_PORT!g" \
 -e "s!@KCOUCHDB_PASSWORD@!$KCOUCHDB_PASSWORD!g" \
 -e "s!@KCOUCHDB_USERID@!$KCOUCHDB_USERID!g" \
 -e "s!@PREFIX@!$PREFIX!g" \
cd-pipeline-kubernetes/environments/local/values.yaml.template >cd-pipeline-kubernetes/environments/local/values.yaml

if [ -e pipeline-artifact-repository-service ]; then
cat - >server/config.local.json <<EOF
{
  "amqp": {
    "enabled": true
  },
  "downloadURL": "http://pipeline-artifact-repository-service",
  "orgURI": "https://api.stage1.ng.bluemix.net/v2/organizations",
  "log_level": "info"
}
EOF

cat - >server/datasources.local.json <<EOF
{
  "db": {
    "database": "${PREFIX}-ars-local"
  }
}
EOF

fi


if [ -e pipeline-service -a -e vault_values.txt ]; then
	cat <(sed '/  travis-worker:/,$d' <cd-pipeline-kubernetes/environments/local/values.yaml ) vault_values.txt  >tmp.txt
	echo "  travis-worker:" >>tmp.txt
	cat <(sed '1,/  travis-worker:/d' <cd-pipeline-kubernetes/environments/local/values.yaml ) >>tmp.txt
	mv tmp.txt cd-pipeline-kubernetes/environments/local/values.yaml
fi
