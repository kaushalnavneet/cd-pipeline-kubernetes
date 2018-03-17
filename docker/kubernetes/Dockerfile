FROM alpine as builder

RUN apk update
RUN apk add ca-certificates openssl wget curl bash
RUN update-ca-certificates  2>/dev/null || true

RUN wget --quiet --output-document /usr/local/bin/kubectl  https://storage.googleapis.com/kubernetes-release/release/$(wget --quiet --output-document - https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

RUN wget --quiet --output-document /tmp/get_helm.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get && \
    chmod +x /tmp/get_helm.sh && /tmp/get_helm.sh

RUN wget --quiet --output-document - https://github.com/git-lfs/git-lfs/releases/download/v2.3.4/git-lfs-linux-amd64-2.3.4.tar.gz | tar xz  && \
    mv git-lfs-*/git-lfs /usr/local/bin && rm -rf git-lfs-*

FROM docker

ENV LANG=en_US.UTF-8

RUN apk update && \
    apk --no-cache add ca-certificates openssl wget curl bash bash-completion git && \
    update-ca-certificates  2>/dev/null || true && \
    GLIBC_VERSION=$(wget --quiet --output-document - "https://api.github.com/repos/sgerrand/alpine-pkg-glibc/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^\"]+)".*/\1/') && echo  \
    wget --quiet --output-document /etc/apk/keys/sgerrand.rsa.pub https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/sgerrand.rsa.pub && \
    wget --quiet \
         https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
         https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-i18n-${GLIBC_VERSION}.apk \
         https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk && \
    apk --allow-untrusted --no-cache add glibc-${GLIBC_VERSION}.apk glibc-bin-${GLIBC_VERSION}.apk glibc-i18n-${GLIBC_VERSION}.apk && \
    rm -f glibc-${GLIBC_VERSION}.apk glibc-bin-${GLIBC_VERSION}.apk glibc-i18n-${GLIBC_VERSION}.apk && \
    /usr/glibc-compat/bin/localedef --force --inputfile ${LANG%.*} --charmap ${LANG#*.} ${LANG} && \
    echo "export LANG=${LANG}" > /etc/profile.d/locale.sh

#ARG DEBIAN_FRONTEND=noninteractive
#RUN apt-get update && apt-get install -y apt-utils && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y && apt-get install -y zip unzip git git-lfs && git lfs install

#
# IBM Cloud regions can be accessed by specifying the API endpoint when you
# log in. If you do not specify a region, you are automatically logged in to
# the region that is closest to you.
#
# You might want to log in to another IBM Cloud Container Service region for
# the following reasons:
# - You created IBM Cloud services or private Docker images in one region
#   and want to use them with IBM Cloud Container Service in another region.
# - You want to access a cluster in a region that is different from the default i
#   IBM Cloud region you are logged in to.
#
# IBM CCS Region Name   Region Alias   IBM Cloud API Endpoint
# ap-north              jp-tok         api.au-syd.bluemix.net
# ap-south              au-syd         api.au-syd.bluemix.net
# eu-central            eu-de          api.eu-de.bluemix.net
# uk-south              eu-gb          api.eu-gb.bluemix.net
# us-east               us-east        api.ng.bluemix.net
# us-south              us-south       api.ng.bluemix.net
#
# Eg.
# ENV com.ibm.cloud.api.endpoint=api.ng.bluemix.net
# ENV com.ibm.cloud.iam.api.key=apikeyvalue
# ENV com.ibm.cloud.container.service.region=us-south
# ENV com.ibm.cloud.container.service.cluster.name=mycluster

ENV com.ibm.cloud.api.endpoint=
ENV com.ibm.cloud.iam.api.key=
ENV com.ibm.cloud.container.service.region=
ENV com.ibm.cloud.container.service.cluster.name=

COPY --from=builder /usr/local/ /usr/local/
RUN wget --quiet -O /tmp/Bluemix_CLI.tar.gz  http://public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/latest/Bluemix_CLI_amd64.tar.gz && \
    tar -xzvf /tmp/Bluemix_CLI.tar.gz -C /tmp && \
    /tmp/Bluemix_CLI/install_bluemix_cli && \
    rm -rf /tmp/Bluemix_CLI* && \
    bx config --check-version false && \
    bx plugin install container-service -r Bluemix && \
    bx plugin install container-registry -r Bluemix && \
    bx plugin install cloud-functions -r Bluemix && \
    bx --version && \
    bx plugin list && \
    helm init --client-only && \
    git lfs install
