###############################################################################
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2018. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
###############################################################################

FROM registry.ng.bluemix.net/opentoolchain/cd-build-base:java as build

ARG DEVELOPMENT=true
ARG JQ_VERSION=jq-1.5


ADD . /work/warbuild

WORKDIR /work/warbuild
ADD https://github.com/stedolan/jq/releases/download/${JQ_VERSION}/jq-linux64 /work/warbuild/jq

# publish logmet and qradar jars to local maven repo
RUN mvn -B clean package

FROM websphere-liberty:kernel

ARG APP_BUILD_NUMBER=latest
ARG MODE=DEVELOPMENT
ARG warname

RUN installUtility install --acceptLicense servlet-3.1 ssl-1.0 jsp-2.2
ENV WLP_OUTPUT_DIR=/opt/ibm/wlp/usr/servers


COPY --from=build /work/warbuild/target/$warname /opt/ibm/wlp/usr/servers/defaultServer/apps
COPY --from=build /work/warbuild/serverConf/*.template /opt/ibm/wlp/usr/servers/defaultServer/
COPY --from=build /work/warbuild/serverConf/pipeline-server /opt/ibm/wlp/
COPY --from=build /work/warbuild/jq /opt/ibm/wlp/
COPY --from=build /work/warbuild/serverConf/resources/security/* /opt/ibm/wlp/usr/servers/defaultServer/resources/security/

RUN chmod 755 /opt/ibm/wlp/pipeline-server /opt/ibm/wlp/jq


ENTRYPOINT ["/opt/ibm/wlp/pipeline-server"]
CMD ["run", "defaultServer"]
