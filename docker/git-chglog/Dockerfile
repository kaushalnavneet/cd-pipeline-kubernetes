############################################################
# Dockerfile
############################################################

# Set the base image
FROM registry.access.redhat.com/ubi8:latest

############################################################
# Installation
############################################################
RUN yum update -y &&\
    yum install git -y &&\
    yum clean all -y &&\
    curl -L -o /usr/local/git-chglog.tar.gz https://github.com/git-chglog/git-chglog/releases/download/v0.10.0/git-chglog_0.10.0_linux_amd64.tar.gz &&\
    tar xvzf usr/local/git-chglog.tar.gz -C /usr/local/bin &&\
    rm usr/local/git-chglog.tar.gz &&\
    chmod +x /usr/local/bin/git-chglog
COPY CHANGELOG.tpl.md config.yml /root/.chglog/

############################################################
# Execution
############################################################
CMD [ "git-chglog", "--help" ]