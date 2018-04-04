#!/bin/sh

# 0
echo "Reset environment on docker-machine"
docker ps | grep -v CONTAINER | awk '{print $1}' | xargs --no-run-if-empty docker stop && docker ps --filter "status=exited" | grep -v CONTAINER | awk '{print $1}' | xargs --no-run-if-empty docker rm \
	&& docker network prune -f 
	
# 1
SUB_NET="172.18.0.0/16"
CLIENT_IP=172.18.0.23
declare -a SERVER_IPS=("172.18.0.101" "172.18.0.102" "172.18.0.103")
WMQ_IP=172.18.0.77
 
# 2
timestamp=$(date +%Y%m%d_%H%M%S)
volume_path=$(pwd)
jmeter_path=/mnt/jmeter
TEST_NET=mydummynet
 
# 3
echo "Create testing network"
docker network create --subnet=$SUB_NET $TEST_NET

# 4
echo "Under Test WMQ"
export ks_file=my-cert.pfx && \
export ks_pass=changeit && \
docker run \
  --env MQ_DISABLE_WEB_CONSOLE=true \
  --env MQ_TLS_KEYSTORE=/var/ks/${ks_file} \
  --env MQ_TLS_PASSPHRASE=${ks_pass} \
  --publish 1414:1414 \
  --publish 1415:1415 \
  --publish 4444:4444 \
  --net $TEST_NET --ip $WMQ_IP \
  --detach \
  --volume qm1data:/mnt/mqm \
  --volume "$(pwd)":/var/ks \
  --name wmq \
  vmarrazzo/wmq

echo "Wait time for IBM MQ boot procedure...."  
read -rsp $'Press any key to continue...\n' -n1 key
  
# 4
echo "Create servers"
for IP_ADD in "${SERVER_IPS[@]}"
do
	docker run \
	-dit \
	--net $TEST_NET --ip $IP_ADD \
	-v "${volume_path}":${jmeter_path} \
	--rm \
	jmeter \
	-n -s \
	-Juser.classpath=${jmeter_path}/shared \
	-Jclient.rmi.localport=7000 -Jserver.rmi.localport=60000 \
    -Jserver.rmi.ssl.disable=true \
	-j ${jmeter_path}/server/slave_${timestamp}_${IP_ADD:9:3}.log 
done

echo "Wait time after JMeter Server boot procedure...."  
read -rsp $'Press any key to continue...\n' -n1 key
  
# 5 
echo "Create client and execute test"
docker run \
  --net $TEST_NET --ip $CLIENT_IP \
  -v "${volume_path}":${jmeter_path} \
  --rm \
  --env JMETER_DEBUG=false \
  --publish 8000:8000 \
  jmeter \
  -LDEBUG \
  -n -X \
  -Juser.classpath=${jmeter_path}/shared \
  -Jclient.rmi.localport=7000 \
  -Jserver.rmi.ssl.disable=true \
  -R $(echo $(printf ",%s" "${SERVER_IPS[@]}") | cut -c 2-) \
  -Gunder_test_host=$WMQ_IP \
  -Jperfmon_host=$WMQ_IP \
  -t ${jmeter_path}/ibmmq_docker_4.0_PerfMon.jmx \
  -l ${jmeter_path}/client/result_${timestamp}.jtl \
  -j ${jmeter_path}/client/jmeter_${timestamp}.log 
 
### --rm \
###  ${__P(wmq_address,127.0.0.1)}
### -JforcePerfmonFile=true \
### -Jperfmon_file=${jmeter_path}/client/result_perfmon_${timestamp}.jtl \
### --env JMETER_DEBUG=true \
###   -LDEBUG \
### -Jperfmon_file=${jmeter_path}/client/result_perfmon_${timestamp}.jtl \
 
# 6
mv ./shared/curr_perfMon_report.jtl ./client/result_perfmon_${timestamp}.jtl
