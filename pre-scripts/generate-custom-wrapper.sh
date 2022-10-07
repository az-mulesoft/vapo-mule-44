#!/usr/bin/bash
cat << EOF > ${MULE_HOME}/conf/wrapper-custom.conf
#encoding=UTF-8
-Danypoint.platform.client_id=$ANYPOINT_CLIENTID
-Danypoint.platform.client_secret=$ANYPOINT_CLIENTSECRET
$MULE_VARS
EOF

