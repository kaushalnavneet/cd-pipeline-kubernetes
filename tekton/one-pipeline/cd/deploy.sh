#!/usr/bin/env bash
echo "deploy"
env
ls -la
pwd
ls -la /artifacts
#jq -rc '.[]' /artifacts/deployment-delta-list.json