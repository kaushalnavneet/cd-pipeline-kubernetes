#!/bin/bash
echo "install helm ${HELM_VERSION}"
mkdir -p /tmp/helm_install
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh --version "${HELM_VERSION}"
rm -rf /tmp/helm*
helm version
helm init