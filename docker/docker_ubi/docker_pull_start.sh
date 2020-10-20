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

docker pull ${WORKER_LEGACY_IMAGE}
docker tag ${WORKER_LEGACY_IMAGE} ibm_devops_services/worker_base:latest
docker pull ${WORKER_DIND_IMAGE}
docker tag ${WORKER_DIND_IMAGE} ibm_devops_services/worker_dind:latest

LEGACY_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 1.0 | sed -e 's#.*=\(\)#\1#'`
LEGACY_BASE_IMAGE_TAG=`echo $WORKER_LEGACY_IMAGE | sed -e 's#.*:\(\)#\1#'`
docker tag ${WORKER_LEGACY_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${LEGACY_BASE_IMAGE_NAME}:${LEGACY_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${LEGACY_BASE_IMAGE_NAME}:${LEGACY_BASE_IMAGE_TAG}

VERSION_2_0_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.0 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_0_BASE_IMAGE_TAG=`echo $WORKER_20_BASE_IMAGE | sed -e 's#.*:\(\)#\1#'`
docker pull ${WORKER_20_BASE_IMAGE}
docker tag ${WORKER_20_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_0_BASE_IMAGE_NAME}:${VERSION_2_0_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_0_BASE_IMAGE_NAME}:${VERSION_2_0_BASE_IMAGE_TAG}

VERSION_2_1_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.1 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_1_BASE_IMAGE_TAG=`echo $WORKER_21_BASE_IMAGE | sed -e 's#.*:\(\)#\1#'`
docker pull ${WORKER_21_BASE_IMAGE}
docker tag ${WORKER_21_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_1_BASE_IMAGE_NAME}:${VERSION_2_1_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_1_BASE_IMAGE_NAME}:${VERSION_2_1_BASE_IMAGE_TAG}

VERSION_2_2_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.2 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_2_BASE_IMAGE_TAG=`echo $WORKER_22_BASE_IMAGE | sed -e 's#.*:\(\)#\1#'`
docker pull ${WORKER_22_BASE_IMAGE}
docker tag ${WORKER_22_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_2_BASE_IMAGE_NAME}:${VERSION_2_2_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_2_BASE_IMAGE_NAME}:${VERSION_2_2_BASE_IMAGE_TAG}

VERSION_2_3_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.3 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_3_BASE_IMAGE_TAG=`echo $WORKER_23_BASE_IMAGE | sed -e 's#.*:\(\)#\1#'`
docker pull ${WORKER_23_BASE_IMAGE}
docker tag ${WORKER_23_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_3_BASE_IMAGE_NAME}:${VERSION_2_3_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_3_BASE_IMAGE_NAME}:${VERSION_2_3_BASE_IMAGE_TAG}

VERSION_2_4_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.4 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_4_BASE_IMAGE_TAG=2.4
docker pull ${WORKER_24_BASE_IMAGE}
docker tag ${WORKER_24_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_4_BASE_IMAGE_NAME}:${VERSION_2_4_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_4_BASE_IMAGE_NAME}:${VERSION_2_4_BASE_IMAGE_TAG}

VERSION_2_5_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.5 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_5_BASE_IMAGE_TAG=2.5
docker pull ${WORKER_25_BASE_IMAGE}
docker tag ${WORKER_25_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_5_BASE_IMAGE_NAME}:${VERSION_2_5_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_5_BASE_IMAGE_NAME}:${VERSION_2_5_BASE_IMAGE_TAG}

VERSION_2_6_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.6 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_6_BASE_IMAGE_TAG=2.6
docker pull ${WORKER_26_BASE_IMAGE}
docker tag ${WORKER_26_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_6_BASE_IMAGE_NAME}:${VERSION_2_6_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_6_BASE_IMAGE_NAME}:${VERSION_2_6_BASE_IMAGE_TAG}

VERSION_2_7_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.7 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_7_BASE_IMAGE_TAG=2.7
docker pull ${WORKER_27_BASE_IMAGE}
docker tag ${WORKER_27_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_7_BASE_IMAGE_NAME}:${VERSION_2_7_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_7_BASE_IMAGE_NAME}:${VERSION_2_7_BASE_IMAGE_TAG}

VERSION_2_8_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.8 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_8_BASE_IMAGE_TAG=2.8
docker pull ${WORKER_28_BASE_IMAGE}
docker tag ${WORKER_28_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_8_BASE_IMAGE_NAME}:${VERSION_2_8_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_8_BASE_IMAGE_NAME}:${VERSION_2_8_BASE_IMAGE_TAG}

VERSION_2_9_BASE_IMAGE_NAME=`echo $WORKER_CURATED_IMAGES | tr ',' $'\n' | grep 2.9 | sed -e 's#.*=\(\)#\1#'`
VERSION_2_9_BASE_IMAGE_TAG=2.9
docker pull ${WORKER_29_BASE_IMAGE}
docker tag ${WORKER_29_BASE_IMAGE} ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_9_BASE_IMAGE_NAME}:${VERSION_2_9_BASE_IMAGE_TAG}
docker push ${WORKER_TRAVIS_REGISTRY_URL}/${VERSION_2_9_BASE_IMAGE_NAME}:${VERSION_2_9_BASE_IMAGE_TAG}