#!/bin/bash

. ${SCRIPTS_HOME}/apFunctions.sh

echo
echo '================= BEGIN ======================='
echo " Mule Runtime De-Registration Script"
echo '==============================================='
echo

setENV || failer "Could not setENV."

echo "* Getting serverId"
serverId=$(getServerId) || failer "Function getServerId failed to retrieve serverId."
echo "serverId=$serverId"

# Remove server from cluster or group
if [ "$runtime_mode" != "NONE" ];then
	echo "EXEC $runtime_mode , $groupOrClusterName"
       	deleteServerFromClusterOrGroup "$runtime_mode" "$groupOrClusterName"
	echo "DONE"
fi

# Deregister mule from ARM
echo "* De-registering Server $serverName ($serverId)..."
unregisterServer
if [ "$?" -eq 0 ]; then
	echo "* De-registering success." 
else
	echo "* De-registering FAILED."
fi


echo
echo '==============================================='
echo " Mule Runtime De-Registration Script"
echo '================== END ========================'
echo
