FROM debian:stable-slim 
#FROM centos:7

# Import necessary packages
RUN if egrep 'CentOS Linux 7|Red Hat Enterprise Linux Server 7' /etc/os-release; then \
	yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
	yum install -y nodejs unzip gettext procps openssl curl jq vim-tiny hostname && \
	yum clean all; \
    elif grep 'Debian GNU/Linux' /etc/os-release; then \
	apt-get update && \
	apt-get install -y --no-install-recommends nodejs unzip gettext procps openssl curl jq vim-tiny && \
	rm -rf /var/lib/apt/lists/*; \
    else \
	echo;\
	cat /etc/os-release;\
	echo;\
	echo "*** Unsupported Docker base image ***";\
	echo "*** Please use Debian stable or RHEL/CentOS 7 or customize Dockerfile ***";\
	echo;\
	exit 1; \
    fi

### Set Environmental variables
ENV JAVA_HOME=/opt/jre
ENV MULE_HOME=/opt/mule
ENV SCRIPTS_HOME=/opt/scripts
ENV PATH="${PATH}:${JAVA_HOME}/bin"


### JAVA and MULE runtime
COPY ./README.md ./source/seed.sh ./source/jre*.tar.gz* ./source/mule-*zip* /tmp/
RUN cd /tmp && \ 
    #if /tmp/jre does not exist then Download it using seed.sh.
    if ! ls jre* 1>/dev/null 2>&1; then \ 	
      echo "JRE does not exist. Downloading..."; \
      ./seed.sh jre; \
    fi; \
    mkdir -p /opt/jre; \
    tar xzf jre*tar.gz --strip-components 1 --directory /opt/jre && \
    if ! ls mule*.zip; then \
      echo "Mule runtime does not exist. Downloading..."; \
      ./seed.sh mule; \
    fi; \
    mkdir -p /tmp/muleunzip && \
    unzip -q mule*.zip -d /tmp/muleunzip/ && \
    mv muleunzip/mule* ${MULE_HOME} && \
    cp -rp ${MULE_HOME}/conf ${MULE_HOME}/conf_bkp
    

### License [Add in README.md so that if license.lic is missing it does not fail. They could be using MULE_LICENSE_B64]
COPY ./README.md ./source/license.lic* ${MULE_HOME}/

### ADD APPS AND CONF
COPY ./apps/* ${MULE_HOME}/apps/
COPY ./domains/* ${MULE_HOME}/domains/
COPY ./conf/* ${MULE_HOME}/conf/
COPY ./stow/* /opt/stow/

### Add scripts
COPY registerMule.sh ${SCRIPTS_HOME}/ 
COPY containerShutdown.sh ${SCRIPTS_HOME}/
COPY apFunctions.sh ${SCRIPTS_HOME}/ 
COPY appDeploy.sh ${SCRIPTS_HOME}/ 
COPY enableFIPS.sh ${SCRIPTS_HOME}/ 
COPY pre-scripts ${SCRIPTS_HOME}/pre-scripts
COPY post-scripts ${SCRIPTS_HOME}/post-scripts

### CLEANUP
RUN rm -rf /tmp/*

ENV PORT 8081
EXPOSE 8081

### Attach node to PCE
### Must not use shell-style CMD/Entrypoint or won't properly trap SIGTERM.
CMD ["/opt/scripts/registerMule.sh"]
