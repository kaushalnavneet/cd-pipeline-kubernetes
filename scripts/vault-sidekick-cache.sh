#!/bin/bash

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
secret=$(kubectl --token ${TOKEN} --namespace ${NAMESPACE} get secret ${VAULT_COMPONENT} -o jsonpath='{.data}')
retVal=$?
if [ $retVal -ne 0 ] || [ -z "$secret" ]; then
  mkdir -p /home/vault/secrets
  /vault-sidekick "$@"
  kubecmd="kubectl --token ${TOKEN} --namespace ${NAMESPACE} create secret generic ${VAULT_COMPONENT}"
  for file in /home/vault/secrets/*.secret; do
    [ -e "$file" ] || continue
    kubecmd="$kubecmd --from-file=$file"
  done
  eval "$kubecmd --dry-run -o json | kubectl apply -f -"
fi
