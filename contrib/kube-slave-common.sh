#!/bin/sh
#
# This file provides functions to automatically discover suitable image streams
# that the Kubernetes plugin will use to create "slave" pods.
# The image streams has to have label "role" set to "jenkins-slave".
#
# The Jenkins container also need permissions to access the OpenShift API to
# list image streams. You have to run this command to allow that:
#
# $ oc policy add-role-to-user edit system:serviceaccount:ci:default -n ci
#
# (where the 'ci' is the namespace where Jenkins runs)

## source: https://github.com/openshift/jenkins/blob/master/2/contrib/jenkins/kube-slave-common.sh

export DEFAULT_SLAVE_DIRECTORY=/tmp
export SLAVE_LABEL="jenkins-slave"

JNLP_SERVICE_NAME=${JNLP_SERVICE_NAME:-JENKINS_JNLP}
JNLP_SERVICE_NAME=`echo ${JNLP_SERVICE_NAME} | tr '[a-z]' '[A-Z]' | tr '-' '_'`
T_HOST=${JNLP_SERVICE_NAME}_SERVICE_HOST
# the '!' handles env variable indirection so we can resolve the nested variable
# see: http://stackoverflow.com/a/14204692
JNLP_HOST=${!T_HOST}
T_PORT=${JNLP_SERVICE_NAME}_SERVICE_PORT
JNLP_PORT=${!T_PORT}

export JNLP_PORT=${JNLP_PORT:-50000}

NODEJS_SLAVE=${NODEJS_SLAVE_IMAGE:-registry.access.redhat.com/openshift3/jenkins-slave-nodejs-rhel7}
MAVEN_SLAVE=${MAVEN_SLAVE_IMAGE:-registry.access.redhat.com/openshift3/jenkins-slave-maven-rhel7}
DOTNET_20_SLAVE=${DOTNET_20_SLAVE:-registry.access.redhat.com/dotnet/dotnet-20-jenkins-slave-rhel7}

JENKINS_SERVICE_NAME=${JENKINS_SERVICE_NAME:-JENKINS}
JENKINS_SERVICE_NAME=`echo ${JENKINS_SERVICE_NAME} | tr '[a-z]' '[A-Z]' | tr '-' '_'`

J_HOST=${JENKINS_SERVICE_NAME}_SERVICE_HOST
JENKINS_SERVICE_HOST=${!J_HOST}

J_PORT=${JENKINS_SERVICE_NAME}_SERVICE_PORT
JENKINS_SERVICE_PORT=${!J_PORT}

# The project name equals to the namespace name where the container with jenkins
# runs. You can override it by setting the PROJECT_NAME variable.
# If there is no environment variable and this container does not run in
# kubernetes, the default value "ci" is used.
if [ -z "${PROJECT_NAME}" ]; then
  if [ -f "${KUBE_SA_DIR}/namespace" ]; then
    export PROJECT_NAME=$(cat "${KUBE_SA_DIR}/namespace")
  else
    export PROJECT_NAME="ci"
  fi
else
  export PROJECT_NAME
fi

export JENKINS_PASSWORD KUBERNETES_SERVICE_HOST KUBERNETES_SERVICE_PORT
export K8S_PLUGIN_POD_TEMPLATES=""
export PATH=$PATH:${JENKINS_HOME}/.local/bin

# generate_kubernetes_config generates a configuration for the kubernetes plugin
function generate_kubernetes_config() {
    local crt_contents=$(cat "${KUBE_CA}")
    echo "
    <org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud>
      <name>openshift</name>
      <templates>
        <org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
          <inheritFrom></inheritFrom>
          <name>maven</name>
          <instanceCap>2147483647</instanceCap>
          <idleMinutes>0</idleMinutes>
          <label>maven</label>
          <serviceAccount>${oc_serviceaccount_name}</serviceAccount>
          <nodeSelector></nodeSelector>
          <volumes/>
          <containers>
            <org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
              <name>jnlp</name>
              <image>${MAVEN_SLAVE}</image>
              <privileged>false</privileged>
              <alwaysPullImage>false</alwaysPullImage>
              <workingDir>/tmp</workingDir>
              <command></command>
              <args>\${computer.jnlpmac} \${computer.name}</args>
              <ttyEnabled>false</ttyEnabled>
              <resourceRequestCpu></resourceRequestCpu>
              <resourceRequestMemory></resourceRequestMemory>
              <resourceLimitCpu></resourceLimitCpu>
              <resourceLimitMemory></resourceLimitMemory>
              <envVars/>
            </org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
          </containers>
          <envVars/>
          <annotations/>
          <imagePullSecrets/>
          <nodeProperties/>
        </org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
        <org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
          <inheritFrom></inheritFrom>
          <name>nodejs</name>
          <instanceCap>2147483647</instanceCap>
          <idleMinutes>0</idleMinutes>
          <label>nodejs</label>
          <serviceAccount>${oc_serviceaccount_name}</serviceAccount>
          <nodeSelector></nodeSelector>
          <volumes/>
          <containers>
            <org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
              <name>jnlp</name>
              <image>${NODEJS_SLAVE}</image>
              <privileged>false</privileged>
              <alwaysPullImage>false</alwaysPullImage>
              <workingDir>/tmp</workingDir>
              <command></command>
              <args>\${computer.jnlpmac} \${computer.name}</args>
              <ttyEnabled>false</ttyEnabled>
              <resourceRequestCpu></resourceRequestCpu>
              <resourceRequestMemory></resourceRequestMemory>
              <resourceLimitCpu></resourceLimitCpu>
              <resourceLimitMemory></resourceLimitMemory>
              <envVars/>
            </org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
          </containers>
          <envVars/>
          <annotations/>
          <imagePullSecrets/>
          <nodeProperties/>
        </org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
        <org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
            <inheritFrom></inheritFrom>
            <name>dotnet-20</name>
            <instanceCap>2147483647</instanceCap>
            <idleMinutes>0</idleMinutes>
            <label>dotnet-20</label>
            <serviceAccount>${oc_serviceaccount_name}</serviceAccount>
            <nodeSelector></nodeSelector>
            <volumes/>
            <containers>
              <org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
                <name>jnlp</name>
                <image>${DOTNET_20_SLAVE}</image>
                <privileged>false</privileged>
                <alwaysPullImage>false</alwaysPullImage>
                <workingDir>/tmp</workingDir>
                <command></command>
                <args>\${computer.jnlpmac} \${computer.name}</args>
                <ttyEnabled>false</ttyEnabled>
                <resourceRequestCpu></resourceRequestCpu>
                <resourceRequestMemory></resourceRequestMemory>
                <resourceLimitCpu></resourceLimitCpu>
                <resourceLimitMemory></resourceLimitMemory>
                <envVars/>
              </org.csanchez.jenkins.plugins.kubernetes.ContainerTemplate>
            </containers>
            <envVars/>
            <annotations/>
            <imagePullSecrets/>
            <nodeProperties/>
          </org.csanchez.jenkins.plugins.kubernetes.PodTemplate>
      </templates>
      <serverUrl>https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}</serverUrl>
      <skipTlsVerify>false</skipTlsVerify>
      <serverCertificate>${crt_contents}</serverCertificate>
      <namespace>${PROJECT_NAME}</namespace>
      <jenkinsUrl>http://${JENKINS_SERVICE_HOST}:${JENKINS_SERVICE_PORT}</jenkinsUrl>
      <jenkinsTunnel>${JNLP_HOST}:${JNLP_PORT}</jenkinsTunnel>
      <credentialsId>1a12dfa4-7fc5-47a7-aa17-cc56572a41c7</credentialsId>
      <containerCap>10</containerCap>
      <retentionTimeout>5</retentionTimeout>
    </org.csanchez.jenkins.plugins.kubernetes.KubernetesCloud>
    "
}

# generate_kubernetes_credentials generates the credentials entry for the
# kubernetes service account.
function generate_kubernetes_credentials() {
  echo "<entry>
      <com.cloudbees.plugins.credentials.domains.Domain>
        <specifications/>
      </com.cloudbees.plugins.credentials.domains.Domain>
      <java.util.concurrent.CopyOnWriteArrayList>
        <org.csanchez.jenkins.plugins.kubernetes.ServiceAccountCredential plugin=\"kubernetes@0.4.1\">
          <scope>GLOBAL</scope>
          <id>1a12dfa4-7fc5-47a7-aa17-cc56572a41c7</id>
          <description></description>
        </org.csanchez.jenkins.plugins.kubernetes.ServiceAccountCredential>
      </java.util.concurrent.CopyOnWriteArrayList>
    </entry>
    "
}