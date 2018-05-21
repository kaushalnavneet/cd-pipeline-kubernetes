#!/bin/bash

TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

mkdir -p /home/vault/secrets
/vault-sidekick "$@"
retVal=$?
if [ $retVal -ne 0 ]; then
  secret=$(kubectl --token ${TOKEN} --namespace ${NAMESPACE} get secret ${VAULT_COMPONENT} -o jsonpath='{.data}')
  retVal=$?
  if [ $retVal -eq 0 ] && [ -z "$secret" ]; then
    retVal=1
  fi
else
  kubecmd="kubectl --token ${TOKEN} --namespace ${NAMESPACE} create secret generic ${VAULT_COMPONENT}"
  for file in /home/vault/secrets/*.secret; do
    [ -e "$file" ] || continue
    kubecmd="$kubecmd --from-file=$file"
  done
  eval "$kubecmd --dry-run -o json | kubectl apply -f -"
  retVal=$?
fi
exit $retVal
