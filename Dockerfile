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
# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=0131801e769febccd38d5128f587c4ac446ac596
# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

## Environment Variables

ENV JENKINS_HOME /var/jenkins_home
ENV JENKINS_SLAVE_AGENT_PORT ${AGENT_PORT}
ENV TINI_VERSION 0.14.0
# tini checksum, download will be validated using it
ENV TINI_SHA 6c41ec7d33e857d4779f14d9c74924cab0c7973485d2972419a3b7c7620ff5fd
# jenkins version being bundled in this docker image
ENV JENKINS_VERSION ${JENKINS_VERSION}
ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental

RUN apk add --no-cache git openssh-client curl unzip bash ttf-dejavu coreutils

# Jenkins is run with USER `jenkins`, UID = 5000
# If you bind mount a volume from the host or a data container, 
# ensure you use the same UID
RUN addGROUP -g ${GID} ${GROUP} \
    && addUSER -h "$JENKINS_HOME" -u ${UID} -G ${GROUP} -s /bin/bash -D ${USER}

# Jenkins home directory is a volume, so configuration and build history 
# can be persisted and survive image upgrades
VOLUME /var/jenkins_home

# `/usr/share/jenkins/ref/` contains all reference configuration we want 
# to set on a fresh new installation. Use it to bundle additional plugins 
# or config file with your custom jenkins Docker image.
RUN mkdir -p /usr/share/jenkins/ref/init.groovy.d


# Use tini as subreaper in Docker container to adopt zombie processes 
RUN curl -fsSL https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-static-amd64 -o /bin/tini && chmod +x /bin/tini \
  && echo "$TINI_SHA  /bin/tini" | sha256sum -c -

COPY init.groovy /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum 
# see https://github.com/docker/docker/issues/8331
RUN curl -fsSL ${JENKINS_URL} -o /usr/share/jenkins/jenkins.war \
  && echo "${JENKINS_SHA}  /usr/share/jenkins/jenkins.war" | sha256sum -c -

RUN chown -R ${USER} "$JENKINS_HOME" /usr/share/jenkins/ref

# for main web interface:
EXPOSE ${HTTP_PORT}

# will be used by attached slave agents:
EXPOSE ${AGENT_PORT}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

USER ${USER}

COPY jenkins-support.sh /usr/local/bin/jenkins-support.sh
COPY jenkins.sh /usr/local/bin/jenkins.sh
ENTRYPOINT ["/bin/tini", "--", "/usr/local/bin/jenkins.sh"]

# from a derived Dockerfile, can use `RUN plugins.sh active.txt` to setup /usr/share/jenkins/ref/plugins from a support bundle
COPY plugins.sh /usr/local/bin/plugins.sh
COPY install-plugins.sh /usr/local/bin/install-plugins.sh