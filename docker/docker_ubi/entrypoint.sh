#!/bin/bash
###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
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

mkdir -p /etc/docker/certs.d/travis-registry:5000
echo -e "$TRAVIS_REG_CERT" > /etc/docker/certs.d/travis-registry:5000/ca.crt

cat > /etc/docker/daemon.json <<EOL
{
    "hosts": ["unix:///var/run/docker.sock", "${DOCKER_HOST}"],
    "mtu": 1400
}
EOL

exec "$@"