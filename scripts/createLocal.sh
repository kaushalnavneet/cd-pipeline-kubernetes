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
cd-pipeline-kubernetes/environments/local/values.yaml.template >cd-pipeline-kubernetes/environments/local/values.yaml

