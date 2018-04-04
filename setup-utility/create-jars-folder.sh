#!/bin/bash

BASE_HOST=http://central.maven.org/maven2/

declare -a JARS_LIST=(
	"javax/jms/javax.jms-api/2.0.1/javax.jms-api-2.0.1.jar"
	"kg/apc/jmeter-plugins-cmn-jmeter/0.5/jmeter-plugins-cmn-jmeter-0.5.jar"
	"kg/apc/jmeter-plugins-graphs-additional/2.0/jmeter-plugins-graphs-additional-2.0.jar"
	"kg/apc/jmeter-plugins-graphs-basic/2.0/jmeter-plugins-graphs-basic-2.0.jar"
	"kg/apc/jmeter-plugins-perfmon/2.1/jmeter-plugins-perfmon-2.1.jar"
	"kg/apc/perfmon/2.2.2/perfmon-2.2.2.jar"
)

for JAR in "${JARS_LIST[@]}"
do
	$(curl -L --silent -O ${BASE_HOST}${JAR})
done

mkdir shared && mv *.jar ./shared/
