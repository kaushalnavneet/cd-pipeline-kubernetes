#!/usr/bin/env bash
echo "deploy"
jq -rc '.[]' /artifacts/deployment-delta-list.json