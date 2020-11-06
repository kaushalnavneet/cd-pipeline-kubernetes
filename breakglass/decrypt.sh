#!/bin/bash
set -eou pipefail

unzip() {
  local payload=$1
  base64 --decode $payload > ./bg_pp.gz
  gunzip ./bg_pp.gz
}

decrypt() {
  local key=$1
  BOG_IV=$(cut -d '.' -f1 bg_pp)
  cut -d '.' -f2 bg_pp > bg_pipeline
  xxd -r -p bg_pipeline bg_pipeline.bin
  TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
  OUTPUTFILE=$TIMESTAMP-"breakglass_cd_pipeline.json"
  openssl enc -d -aes-256-cbc -iv $BOG_IV  -K $key  -in bg_pipeline.bin -out $OUTPUTFILE
  rm bg_pp
  rm bg_pipeline
  rm bg_pipeline.bin
  FINALNAME=$(cat $OUTPUTFILE | jq -r '.metadata.name')
  mv $OUTPUTFILE $FINALNAME.json
}

if [[ $# -ne 2 ]]; then
  echo "usage: decrypt.sh [pipeline_payload] [encryption key]"
  exit 1
fi

payload=$1
key=$2
      
echo "==============================="
echo "Extracting..."
unzip $payload

echo "Decrypting" 
decrypt $key

echo "==============================="

         
