#!/usr/bin/env bash
echo "deploy"
env
ls -la
pwd
cd /workspace/app
ls -la
#jq -rc '.[]' /artifacts/deployment-delta-list.json