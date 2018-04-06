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

ADD . /work/warbuild

WORKDIR /work/warbuild

# publish logmet and qradar jars to local maven repo
RUN mvn -B clean package

FROM websphere-liberty:kernel

ARG APP_BUILD_NUMBER=latest
ARG MODE=DEVELOPMENT
ARG warname

COPY --from=build /work/warbuild/target/$warname /opt/ibm/wlp/usr/servers/defaultServer/apps
