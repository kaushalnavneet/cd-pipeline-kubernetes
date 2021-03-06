#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2017, 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################

if [ -d /etc/secrets ]; then
    for file in /etc/secrets/*.secret; do
        [ -e "$file" ] || continue
        eval "$(jq -r  '. | to_entries | .[] | "export " + .key + "=" + ( .value|if (type|. != "string") then tostring else .|tojson end)' < $file)"
    done
fi

#Component specific entry point script
COMPONENT_ENTRY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/entrypoint.component.sh"
if [ -f $COMPONENT_ENTRY ]; then
    source $COMPONENT_ENTRY
fi

exec "$@"
