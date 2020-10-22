#!/bin/bash
if [ -d /etc/secrets ]; then
  for file in /etc/secrets/*.secret; do
    [ -e "$file" ] || continue
    eval "$(/root/jq -r  '. | to_entries | .[] | "export " + .key + "=" + ( .value|if (type|. != "string") then tostring else .|tojson end)' < $file)"
  done
fi
ln -sfn /tmp/cloud.ibm.com/travis-worker/.dockercfg /root/.dockercfg
for ITER in {1..6}; do
  docker info >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    break
  fi
  echo "Waiting 1s for docker daemon..."
  sleep 10
done

docker info >/dev/null 2>&1
[ $? -eq 0 ] || exit 1

# get list of all existing images
docker images >images.txt
cat images.txt > /proc/1/fd/1
docker pull ${WORKER_LEGACY_IMAGE}
docker tag ${WORKER_LEGACY_IMAGE} ibm_devops_services/worker_base:latest
docker pull ${WORKER_DIND_IMAGE}
docker tag ${WORKER_DIND_IMAGE} ibm_devops_services/worker_dind:latest

pullImage ${WORKER_LEGACY_IMAGE} 1.0 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_20_BASE_IMAGE} 2.0 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_21_BASE_IMAGE} 2.1 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_22_BASE_IMAGE} 2.2 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_23_BASE_IMAGE} 2.3 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_24_BASE_IMAGE} 2.4 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_25_BASE_IMAGE} 2.5 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_26_BASE_IMAGE} 2.6 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_27_BASE_IMAGE} 2.7 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_28_BASE_IMAGE} 2.8 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}
pullImage ${WORKER_29_BASE_IMAGE} 2.9 ${WORKER_CURATED_IMAGES} ${WORKER_TRAVIS_REGISTRY_URL}

function pullImage {
  local vbi_name=$1
  local version=$2
  local curated_images=$3
  local registry_url=$4
  echo "vbi name: ${vbi_name}" > /proc/1/fd/1
  echo "vbi version: ${version}" > /proc/1/fd/1
  echo "curated_images: ${curated_images}" > /proc/1/fd/1
  echo "registry_url: ${registry_url}" > /proc/1/fd/1

  local base_image_name=`echo ${curated_images} | tr ',' $'\n' | grep ${version} | sed -e 's#.*=\(\)#\1#'`
  local base_image_tag=`echo ${vbi_name} | sed -e 's#.*:\(\)#\1#'`
  cat images.txt | grep "${registry_url}/${base_image_name}" | grep ${base_image_tag} > /proc/1/fd/1 
  exits=$(cat images.txt | grep "${registry_url}/${base_image_name}" | grep ${base_image_tag})
  if [[ $? -ne 0 ]]; then
    docker pull ${vbi_name}
    docker tag ${vbi_name} ${registry_url}/${base_image_name}:${base_image_tag}
    docker push ${registry_url}/${base_image_name}:${base_image_tag}
  fi
}