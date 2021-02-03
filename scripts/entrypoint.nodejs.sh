#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017, 2021. All Rights Reserved.
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

export HOST_INSTANCE=${HOSTNAME##*-}

exec "$@"
