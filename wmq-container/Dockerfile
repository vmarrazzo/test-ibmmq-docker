FROM ibmcom/mq

LABEL maintainer="Vincenzo Marrazzo <pariamentz@gmail.com>"

# Config related IBM MQ
ENV LICENSE=accept
ENV MQ_QMGR_TLS_NAME=QM_WITH_TLS
ENV MQ_QMGR_NO_TLS_NAME=QM_WITHOUT_TLS
ENV MQ_APP_PASSWORD=test

# Server Agent
ENV SERVER_AGENT_VERSION=2.2.1
ENV SERVER_AGENT_DOWNLOAD_URL=https://jmeter-plugins.org/downloads/file/ServerAgent-${SERVER_AGENT_VERSION}.zip

RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update -y \
	&& apt-get install -y --no-install-recommends \
	htop \
	net-tools \
	wget \
	unzip \
	&& wget --no-check-certificate ${SERVER_AGENT_DOWNLOAD_URL} -O /tmp/ServerAgent-${SERVER_AGENT_VERSION}.zip \
	&& unzip /tmp/ServerAgent-${SERVER_AGENT_VERSION}.zip -d /opt/ServerAgent/ 

COPY *.sh /usr/local/bin/

COPY mq-dev-config /etc/mqm/mq-dev-config
COPY mq-dev-tls-config /etc/mqm/mq-dev-tls-config

COPY admin.json /etc/mqm/

# copy server agent script
COPY testFacilities/startAgent.sh /opt/ServerAgent/
	
# Exposed ports:
# Port 1414 for QM_WITHOUT_TLS
# Port 1415 for QM_WITH_TLS
# Port 4444 for PerfMon plugins
# Port 9443 for the web console
EXPOSE 1414 1415 4444 9443
