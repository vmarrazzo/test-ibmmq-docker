#!/bin/bash
# -*- mode: sh -*-
# © Copyright IBM Corporation 2015, 2017
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

script_name="mq-start-qmgr"

if [ ${MQ_QMGR_CMDLEVEL+x} ]; then
  # Enables the specified command level, then stops the queue manager
  strmqm -e CMDLEVEL=${MQ_QMGR_CMDLEVEL} || true
fi

for MQ_QMGR_NAME in ${MQ_QMGR_TLS_NAME} ${MQ_QMGR_NO_TLS_NAME}; do
	echo "($script_name) Starting queue manager $MQ_QMGR_NAME"
	strmqm ${MQ_QMGR_NAME}
done