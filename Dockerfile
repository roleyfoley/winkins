# escape=` 
# Escape as backtick for windows folder parth consistency 

FROM openjdk:8-windowsservercore-1709

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

ARG user=jenkins
ARG http_port=8080
ARG agent_port=50000
ARG JENKINS_HOME="C:/Program Files/Jenkins/jenkins_home"

ENV JENKINS_HOME $JENKINS_HOME
ENV JENKINS_SLAVE_AGENT_PORT ${agent_port}

# Jenkins is run with user `jenkins`
# If you bind mount a volume from the host or a data container,
# ensure you use the same uid
RUN NET USER $ENV:user /add

# Jenkins home directory is a volume, so configuration and build history
# can be persisted and survive image upgrades
VOLUME $JENKINS_HOME

# `C:\Program Files\Jenkins\ref\` contains all reference configuration we want
# to set on a fresh new installation. Use it to bundle additional plugins
# or config file with your custom jenkins Docker image.
RUN @( 'C:/Program Files/Jenkins/ref/init.groovy.d', 'C:/Program Files/Jenkins/ref/bin' ) | `
    ForEach-Object ${ New-Item -ItemType Directory -Path $_ }

COPY [ "init.groovy", "C:/Program Files/Jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy" ]

# jenkins version being bundled in this docker image
ARG JENKINS_VERSION
ENV JENKINS_VERSION ${JENKINS_VERSION:-2.60.3}

# jenkins.war checksum, download will be validated using it
ARG JENKINS_SHA=2d71b8f87c8417f9303a73d52901a59678ee6c0eefcf7325efed6035ff39372a

# Can be used to customize where jenkins.war get downloaded from
ARG JENKINS_URL=https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war

# could use ADD but this one does not check Last-Modified header neither does it allow to control checksum
# see https://github.com/docker/docker/issues/8331
RUN Invoke-WebRequest $ENV:JENKINS_URL -OutFile 'C:/Program Files/Jenkins/jenkins.war'; `
  $Hash = Get-FileHash -Algorithm SHA256 -Path 'C:/Program Files/Jenkins/jenkins.war'; `
  if ( $Hash.Hash -ne $ENV:JENKINS_SHA ) { write-Error 'Jenkns File does not match expected hash' }

ENV JENKINS_UC https://updates.jenkins.io
ENV JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimental

# for main web interface:
EXPOSE ${http_port}

# will be used by attached slave agents:
EXPOSE ${agent_port}

ENV COPY_REFERENCE_FILE_LOG $JENKINS_HOME/copy_reference_file.log

COPY [ "jenkins-support.ps1", "C:/Program Files/Jenkins/bin/jenkins-support.ps1" ]
COPY [ "jenkins.ps1", "C:/Program Files/Jenkins/bin/jenkins.ps1" ]

# from a derived Dockerfile, can use `RUN install-plugins.sh plugins.txt` to setup C:\Program Files\Jenkins\ref\plugins from a support bundle
COPY [ "install-plugins.ps1", "C:/Program Files/Jenkins/bin/install-plugins.ps1" ]

RUN @( $ENV:JENKINS_HOME, 'C:/Program Files/Jenkins/ref', 'C:/Program Files/Jenkins/bin' ) | ForEach-Object { `
        $acl = Get-Acl $_; `
        $permission = $ENV:user,'FullControl','Allow'; `
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission; `
        $acl.SetAccessRule($accessRule); `
        $acl | Set-Acl $_ `
    }

RUN $newPath = ('{0}\bin;{1}' -f 'C:\Program Files\Jenkins', $env:PATH); `
	Write-Host ('Updating PATH: {0}' -f $newPath); `
    # Nano Server does not have "[Environment]::SetEnvironmentVariable()"
    setx /M PATH $newPath;

USER ${user}

ENTRYPOINT powershell -File 'C:/Program Files/Jenkins/bin/jenkins.ps1' 
