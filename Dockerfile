FROM stakater/oracle-jdk:8u144-alpine-3.6

MAINTAINER Stakater Team

## Arguments

ARG USER=jenkins
ARG GROUP=jenkins
# why 386? Please read: https://github.com/jenkinsci/docker/issues/112#issuecomment-228553691
ARG UID=386
ARG GID=386
ARG HTTP_PORT=8080
ARG AGENT_PORT=50000
ARG JENKINS_VERSION=2.92
# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

## Environment Variables

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${AGENT_PORT}
# jenkins version being bundled in this docker image
ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental
ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

RUN apk add --no-cache git openssh-client curl unzip bash ttf-dejavu coreutils

# Jenkins is run with USER `jenkins`, UID = 386
# If you bind mount a volume from the host or a data container, 
# ensure you use the same UID
RUN addgroup -g ${GID} ${GROUP} \
    && adduser -h "$JENKINS_HOME" -u ${UID} -G ${GROUP} -s /bin/bash -D ${USER}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d

## TODO: is this needed? why is it needed?
COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war

RUN chown -R ${USER} "$JENKINS_HOME" /usr/share/jenkins/ref

## Expose

# for main web interface:
EXPOSE ${HTTP_PORT}
# will be used by attached slave agents:
EXPOSE ${AGENT_PORT}

## TODO: should clean this up?

COPY ./contrib /usr/local/bin

## TODO - need to fix following:

# Make daemon service dir for jenkins and place file
# It will be started and maintained by the base image
# RUN mkdir -p /etc/service/jenkins
# ADD jenkins.sh /etc/service/jenkins/run

USER ${USER}

# ENTRYPOINT ["/usr/local/bin/run.sh"]
ENTRYPOINT []
CMD ["/usr/local/bin/run.sh"]