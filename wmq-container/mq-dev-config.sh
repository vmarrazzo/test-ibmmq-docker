#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2017
#
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

script_name="mq-dev-config"

configure_os_user()
{
  # The group ID of the user to configure
  local -r GROUP_NAME=$1
  # Name of environment variable containing the user name
  local -r USER_VAR=$2
  # Name of environment variable containing the password
  local -r PASSWORD=$3
  # Home directory for the user
  local -r HOME=$4
  # Determine the login name of the user (assuming it exists already)

  # if user does not exist
  if ! id ${!USER_VAR} 2>1 > /dev/null; then
    # create
    useradd --gid ${GROUP_NAME} --home ${HOME} ${!USER_VAR}
  fi
  # Change the user's password (if set)
  if [ ! "${!PASSWORD}" == "" ]; then
    echo ${!USER_VAR}:${!PASSWORD} | chpasswd
  fi
}

configure_tls()
{
  local -r PASSPHRASE=${MQ_TLS_PASSPHRASE}
  local -r LOCATION=${MQ_TLS_KEYSTORE}

  if [ ! -e ${LOCATION} ]; then
    echo "($script_name) Error: The key store '${LOCATION}' referenced in MQ_TLS_KEYSTORE does not exist"
    exit 1
  fi

  # Create keystore
  if [ ! -e "/tmp/tlsTemp/key.kdb" ]; then
    # Keystore does not exist
    runmqakm -keydb -create -db /tmp/tlsTemp/key.kdb -pw ${PASSPHRASE} -stash
  fi

  # Create stash file
  if [ ! -e "/tmp/tlsTemp/key.sth" ]; then
    # No stash file, so create it
    runmqakm -keydb -stashpw -db /tmp/tlsTemp/key.kdb -pw ${PASSPHRASE}
  fi

  # Import certificate
  runmqakm -cert -import -file ${LOCATION} -pw ${PASSPHRASE} -target /tmp/tlsTemp/key.kdb -target_pw ${PASSPHRASE}

  # Find certificate to rename it to something MQ can use
  CERT=`runmqakm -cert -list -db /tmp/tlsTemp/key.kdb -pw ${PASSPHRASE} | egrep -m 1 "^\\**-"`
  CERTL=`echo ${CERT} | sed -e s/^\\**-//`
  CERTL=${CERTL:1}
  echo "($script_name) Using certificate with label ${CERTL}"

  # Rename certificate
  runmqakm -cert -rename -db /tmp/tlsTemp/key.kdb -pw ${PASSPHRASE} -label "${CERTL}" -new_label queuemanagercertificate

  # Now copy the key files
  chown mqm:mqm /tmp/tlsTemp/key.*
  chmod 640 /tmp/tlsTemp/key.*
  su -c "cp -PTv /tmp/tlsTemp/key.kdb ${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.kdb" -l mqm
  su -c "cp -PTv /tmp/tlsTemp/key.sth ${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.sth" -l mqm

  # Set up Dev default MQ objects
  # Make channel TLS CHANNEL
  # Create SSLPEERMAP Channel Authentication record
  if [ "${MQ_DEV}" == "true" ]; then
    su -l mqm -c "echo \"ALTER CHANNEL('DEV.APP.SVRCONN') CHLTYPE(SVRCONN) SSLCIPH(TLS_RSA_WITH_AES_256_GCM_SHA384) SSLCAUTH(OPTIONAL)\" | runmqsc ${MQ_QMGR_TLS_NAME}"
    su -l mqm -c "echo \"ALTER CHANNEL('DEV.ADMIN.SVRCONN') CHLTYPE(SVRCONN) SSLCIPH(TLS_RSA_WITH_AES_256_GCM_SHA384) SSLCAUTH(OPTIONAL)\" | runmqsc ${MQ_QMGR_TLS_NAME}"
  fi
}

# Check valid parameters
if [ ! -z ${MQ_TLS_KEYSTORE+x} ]; then
  : ${MQ_TLS_PASSPHRASE?"Error: If you supply MQ_TLS_KEYSTORE, you must supply MQ_TLS_PASSPHRASE"}
fi

# Set default unless it is set
MQ_DEV=${MQ_DEV:-"true"}
MQ_ADMIN_NAME="admin"
MQ_ADMIN_PASSWORD=${MQ_ADMIN_PASSWORD:-"passw0rd"}
MQ_APP_NAME="app"
MQ_APP_PASSWORD=${MQ_APP_PASSWORD:-""}

# Set needed variables to point to various MQ directories
DATA_PATH=`dspmqver -b -f 4096`
INSTALLATION=`dspmqver -b -f 512`

if [ "${MQ_DEV}" == "true" ]; then
  echo "($script_name) Configuring app user"
  if ! getent group mqclient; then
    # Group doesn't exist already
    groupadd mqclient
  fi
  configure_os_user mqclient MQ_APP_NAME MQ_APP_PASSWORD /home/app

  for MQ_QMGR_NAME in ${MQ_QMGR_TLS_NAME} ${MQ_QMGR_NO_TLS_NAME}; do
	
	  echo "($script_name) Set authorities to give access to qmgr, queues and topic for ${MQ_QMGR_NAME}"

      # Set authorities to give access to qmgr, queues and topic
      su -l mqm -c "setmqaut -m ${MQ_QMGR_NAME} -t qmgr -g mqclient +connect +inq"
      su -l mqm -c "setmqaut -m ${MQ_QMGR_NAME} -n \"DEV.**\" -t queue -g mqclient +put +get +browse +inq"
  done

  echo "($script_name) Configuring admin user"
  configure_os_user mqm MQ_ADMIN_NAME MQ_ADMIN_PASSWORD /home/admin

  if [ -z ${MQ_QMGR_TLS_NAME+x} ]; then 
  	   echo "($script_name) MQ_QMGR_TLS_NAME is unset" 
  else 
  	   echo "($script_name) Configuring default objects for queue manager: ${MQ_QMGR_TLS_NAME}"
       set +e
       runmqsc ${MQ_QMGR_TLS_NAME} < /etc/mqm/mq-dev-tls-config 
  fi
  
  if [ -z ${MQ_QMGR_NO_TLS_NAME+x} ]; then 
  	   echo "($script_name) MQ_QMGR_NO_TLS_NAME is unset" 
  else
  	   echo "($script_name) Configuring default objects for queue manager: ${MQ_QMGR_NO_TLS_NAME}"
       set +e
       runmqsc ${MQ_QMGR_NO_TLS_NAME} < /etc/mqm/mq-dev-config 
  fi

  set -e
fi # end main "if"

# no persistence for tls queue manager
# always setup TLS
# delete existing key information
rm -rf ${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.sth 2> /dev/null
rm -rf ${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.kdb 2> /dev/null
rm -rf /tmp/tlsTemp 2> /dev/null

if [ ! -z ${MQ_TLS_KEYSTORE+x} ]; then
  if [ ! -e "${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.kdb" ]; then
    echo "($script_name) Configuring TLS for queue manager ${MQ_QMGR_TLS_NAME}"
    mkdir -p /tmp/tlsTemp
    chown mqm:mqm /tmp/tlsTemp
    configure_tls
  else
    echo "($script_name) A key store already exists at '${DATA_PATH}/qmgrs/${MQ_QMGR_TLS_NAME}/ssl/key.kdb'"
  fi
fi
