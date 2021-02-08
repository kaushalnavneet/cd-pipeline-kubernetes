############################################################
# Dockerfile
############################################################

# Set the base image
FROM docker.io/alpine:latest

############################################################
# Installation
############################################################
RUN apk add --no-cache bash curl git > /dev/null &&\
    curl -L -o /usr/local/git-chglog.tar.gz https://github.com/git-chglog/git-chglog/releases/download/v0.10.0/git-chglog_0.10.0_linux_amd64.tar.gz &&\
    tar xvzf usr/local/git-chglog.tar.gz -C /usr/local/bin &&\
    rm usr/local/git-chglog.tar.gz &&\
    chmod +x /usr/local/bin/git-chglog &&\
    apk del --no-cache curl > /dev/null
COPY CHANGELOG.tpl.md config.yml /root/.chglog/

############################################################
# Execution
############################################################
CMD [ "git-chglog", "--help" ]