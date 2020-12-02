#!/bin/bash
#checks if LOGDNA_EXCLUDE has already been added and if not patches and restarts the daemon-set
kubectl get ds logdna-agent -ojson | jq -e '.spec.template.spec.containers[0].env[] | select(.name=="LOGDNA_EXCLUDE")' || 
(
kubectl patch ds logdna-agent --type "json" -p '[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"LOGDNA_EXCLUDE","value":"/var/log/containers/pw-*/**"}}]' &&
kubectl delete pod -l app=logdna-agent
)