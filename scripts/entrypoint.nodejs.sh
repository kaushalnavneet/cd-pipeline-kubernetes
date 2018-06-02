#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################

if [ -d /etc/secrets ]; then
    for file in /etc/secrets/*.secret; do
        [ -e "$file" ] || continue
        eval "$(/home/node/jq -r  '. | to_entries | .[] | "export " + .key + "=" + ( .value|if (type|. != "string") then tostring else .|tojson end)' < $file)"
    done
fi

read -d '' vcap_services_template <<"EOF"
    "%s": [
        {
            "credentials": {
	       "pipeline":{  
               	 "initial":null,
                 "secret":"%s"
               }
	    },
            %s
        }
    ]
EOF

printf -v VCAP_SERVICES "{$vcap_services_template}" "user-provided" "$vcap_pipeline_secret" "\"name\": \"otc-tiam-clients\""

export VCAP_SERVICES
CF_INSTANCE_INDEX=$(hostname | grep -o "[[:digit:]]*$")

#Avoid queue conflicts with CF instances
CF_INSTANCE_INDEX=$((CF_INSTANCE_INDEX+100))

export VCAP_SERVICES CF_INSTANCE_INDEX

exec "$@"
