#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################
#wait 5 seconds for vault
sleep 5

if [ -d /etc/secrets ]; then
    for file in /etc/secrets/*.secret; do
        [ -e "$file" ] || continue
        eval "$(jq -r  '. | to_entries | .[] | "export " + .key + "=" + ( .value|if (type|. != "string") then tostring else "\""+.+"\"" end)' < $file)"
    done
fi

read -d '' vcap_services_template <<"EOF"
    "%s": [
        {
            "credentials": %s,
            %s
        }
    ]
EOF

printf -v VCAP_SERVICES "{$vcap_services_template}" "user-provided" "$OTC_TIAM_CLIENTS" "\"name\": \"otc-tiam-clients\""

CF_INSTANCE_INDEX=$(hostname | grep -o "[[:digit:]]*$")

#Avoid queue conflicts with CF instances
CF_INSTANCE_INDEX=$((CF_INSTANCE_INDEX+100))

export VCAP_SERVICES CF_INSTANCE_INDEX

#Component specific entry point script
COMPONENT_ENTRY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/entrypoint.component.sh"
if [ -f $COMPONENT_ENTRY ]; then
    source $COMPONENT_ENTRY
fi

exec "$@"
