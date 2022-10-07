#!/bin/bash

## Fail if an unset variable is used.
set -u

echo
echo '================= BEGIN ======================='
echo " Mule Runtime Registration Script"
echo '==============================================='

# Run Pre-Scripts
echo "* Pre-Script Execution"
for pscript in $(find ${SCRIPTS_HOME}/pre-scripts/ -type f -executable -name "*.sh" 2>&1); do
        echo " - Executing script: $pscript"
        . "$pscript" || { echo "Script: $pscript FAILED. Exit Code: $?"; exit 1;}
        echo
done
echo

## Source in apFunctions.sh
echo "* Importing functions"
. ${SCRIPTS_HOME}/apFunctions.sh || { echo "Could not source apFunctions.sh.sh. FAILING."; exit 1; }
echo 
echo "* Setting environmental variables"
## Initialize Environmental variables
setENV || failer "Could not setENV."

# ###############################
# BEGIN STARTUP SEQUENCE
# ###############################
echo "* Updating keystore"
echo "JAVA_AUTO_TRUST == $JAVA_AUTO_TRUST" 

if [ "$JAVA_AUTO_TRUST" == "true" ]; then
	### Update JDK certificate store
	keystore="${JAVA_HOME}/lib/security/cacerts"
	openssl_output=$(openssl s_client -connect ${ANYPOINT_HOST}:${ANYPOINT_PORT} </dev/null 2>/dev/null |sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p'| keytool -import -noprompt -alias mule_rtc -keystore $keystore -storepass changeit)
	if [ $? -eq 0 ]; then
		echo "* Keystore update Success"
	else
		echo "ERROR:  $openssl_output"
		echo "$openssl_output" | grep 'already exists' 2>/dev/null >/dev/null
		if [ $? -eq 0 ]; then
			echo "Certificate alias mule_rtc already exists in $keystore"
			echo "Verify this is intended."
			sleep 3
		else
			failer "Could not update keystore: $keystore"
		fi
	fi
elif [ "$JAVA_AUTO_TRUST" == "false" ]; then
	echo "* Skipped auto-import of Control Plane cert."
else
	failer "JAVA_AUTO_TRUST must be either 'true' or 'false'"
fi
echo

### Mule executables do not return proper error codes using $?. So have to judge success based on output string comparisons.

# Import license
echo "* Processing License"
echo "SKIP_LICENSE == $SKIP_LICENSE"
if [ "$SKIP_LICENSE" == "true" ]; then
	echo "* Skipping License update"
elif [ "$SKIP_LICENSE" == "false" ]; then
	licenseFile="${MULE_HOME}/license.lic"
	if [ -n "$MULE_LICENSE_B64" ]; then
		echo "* \$MULE_LICENSE_B64 is set. Overwriting any embedded license.lic."
		echo "$MULE_LICENSE_B64" | base64 -d > $licenseFile || failer "Could not decode base64 \$MULE_LICENSE_B64 to $licenseFile"
	elif [ -s $licenseFile ]; then
		echo "* \$MULE_LICENSE_B64 is unset."
		echo "* $licenseFile found and is not empty."
	else
		failer "No license found. Please set \$MULE_LICENSE_B64 or a valid $licenseFile in the image."
	fi

	cp ${licenseFile} ${licenseFile}.import || failer "Could not created copy of license.lic as license.lic.import"
	echo "* Executing mule -installLicense"
	license_output="$($MULE_HOME/bin/mule -installLicense ${licenseFile}.import)"
	contains "$license_output" "Installed license key" || failer "License update failed.\n$license_output"
	contains "$license_output" "Couldn't install license key" && failer "License update failed.\n$license_output"
	echo "* License update successful."

else
	failer "SKIP_LICENSE must be either 'true' or 'false'"
fi
echo

echo "* FIPS_ENABLED is [${FIPS_ENABLED}]"
if [ $FIPS_ENABLED = "true" ];then
	echo "* Enabling FIPS in wrapper.conf"
	wrapperConfSetAdditional "-Dmule.security.model=fips140-2" || failer "Could not set FIPS in wrapper.conf" 
	echo "* Appending '--fips' to AMC_OPTS"
	AMC_OPTS="--fips ${AMC_OPTS}" 
	echo "AMC_OPTS=[${AMC_OPTS}]"

	echo	
	echo "* FIPS_AUTOCONFIG_JAVA = ${FIPS_AUTOCONFIG_JAVA}"
	if [ $FIPS_AUTOCONFIG_JAVA = "true" ]; then
		echo "* Attempting to automatically configure $JAVA_HOME with a FIPS Provider"
		${SCRIPTS_HOME}/enableFIPS.sh || failer "Failed to deploy FIPS configuration to Java"	
	fi	
else
	echo "* Not enabling FIPS"
fi
echo

echo -n "* Checking for ${MULE_HOME}/conf/mule-agent.yml - "
if [ -f ${MULE_HOME}/conf/mule-agent.yml ]; then
	echo "FOUND" 
	MULE_CONF_EXISTS=true
else
	echo "NOT FOUND"
	MULE_CONF_EXISTS=false
fi

echo -n "* Checking if ${serverName} was registered previously to $ANYPOINT_HOST - "
if serverId=$(getServerId); then
	echo "YES  ServerId=${serverId}"
	MULE_PREREGISTERED=true
else
	echo "NO"
	MULE_PREREGISTERED=false
fi

echo
echo "* MULE_CONF_EXISTS = ${MULE_CONF_EXISTS}   MULE_PREREGISTERED = ${MULE_PREREGISTERED}"
if [ $MULE_CONF_EXISTS = 'true' ] && [ $MULE_PREREGISTERED = 'true' ]; then
	echo "* Registration not necessary. Skipping to run mule."
	MULE_NEED_REGISTRATION=false
elif [ $MULE_CONF_EXISTS = 'true' ] && [ $MULE_PREREGISTERED = 'false' ]; then
	echo "* Deleting mule-agent.yml prior to registration."
	rm ${MULE_HOME}/conf/mule-agent.yml
	MULE_NEED_REGISTRATION=true
elif [ $MULE_CONF_EXISTS = 'false' ] && [ $MULE_PREREGISTERED = 'true' ]; then
	echo "* Server was previously registered (serverId=${serverId}) but mule-agent.yml does not exist. Unregistering."
	echo
        echo "============ RUNNING DE-REGISTRATION SCRIPT ===============" 
	${SCRIPTS_HOME}/containerShutdown.sh || failer "Could not unregister server."
        echo "============ ENDED DE-REGISTRATION SCRIPT ===============" 
	echo
	echo "* Continuing registration in 5 seconds."
	MULE_NEED_REGISTRATION=true
        sleep 5
elif [ $MULE_CONF_EXISTS = 'false' ] && [ $MULE_PREREGISTERED = 'false' ]; then
	echo "* New server and not registered in ${ANYPOINT_HOST}. Continuing with registration."
	MULE_NEED_REGISTRATION=true
fi
echo

if [ $MULE_NEED_REGISTRATION = 'true' ]; then
	# Register new mule
	echo -n "* Registering $serverName to Anypoint Platform to "

	if [ "$PLATFORM_TYPE" = "PCE" ]; then
		echo "PCE"
		registration_output=$($MULE_HOME/bin/amc_setup ${AMC_OPTS} -A https://$ANYPOINT_HOST/hybrid/api/v1 -W "wss://$ANYPOINT_HOST:8889/mule" -D https://$ANYPOINT_HOST/apigateway/ccs -F https://$ANYPOINT_HOST/apiplatform -C https://$ANYPOINT_HOST/accounts -H "$amcToken" "$serverName" 2>&1)
	elif [ "$PLATFORM_TYPE" = "GOVCLOUD" ]; then
		echo "GOVCLOUD"
		registration_output=$($MULE_HOME/bin/amc_setup --region us_gov ${AMC_OPTS} -H "$amcToken" "$serverName" 2>&1)
	else
		echo "CLOUDHUB"
		registration_output=$($MULE_HOME/bin/amc_setup ${AMC_OPTS} -H "$amcToken" "$serverName" 2>&1)
	fi


	### would usually use =~/bash regex but it's non-POSIX.
	contains "$registration_output" "Mule Agent configured successfully" || failer "Runtime Registration failed!\n${registration_output}"
	contains "$registration_output" "ERROR:" && failer "Runtime Registration failed!\n${registration_output}"
	serverId=$(getServerId) || failer "Could not get serverId"
	echo "* Registration successful (serverId = $serverId)"
	echo
fi

# Analytics Wrapper Update
if [ "$ANALYTICS_ENABLED" = "true" ]; then
	echo "* Updating wrapper.conf for API Analytics"
	wrapperConfSetAdditional "-Danypoint.platform.analytics_enabled=true" || failer "Failed to update wrapper.conf"
	wrapperConfSetAdditional "-Danypoint.platform.analytics_base_uri=" || failer "Failed to update wrapper.conf"
fi

# Start mule runtime
echo "* Starting mule runtime in background."
nohup $MULE_HOME/bin/mule ${MULE_OPTS} console >/dev/null 2>/dev/null &
sleep 10 
pid=$(/usr/bin/env pgrep 'wrapper-linux') || failer "Could not get PID of backgrounded runtime. PID: $pid"
echo "* Started mule runtime in background. PID: $pid"
echo

echo "* Waiting for Server to show as \"RUNNING\" in Runtime Manager..."
jqParam=".data[] | select(.name==\"$serverName\")"
while true
do
  serverId=$(getServerId)
  serverStatus=$(getServerStatus)
  echo
  echo "  serverId=$serverId"
  echo "  serverStatus=$serverStatus"
  sleep 5
  #[[ "$serverId" != "" && $serverStatus == "RUNNING" ]] && break || continue
  [ "$serverId" != "" -a $serverStatus = "RUNNING" ] && break || continue
done
echo
echo "* Mule Runtime shows as RUNNING in Anypoint Platform. Allowing time for synchronization to stabilize."
sleep 10 
echo

# Add server to group or cluster if mode is not NONE
if [ "$runtime_mode" != "NONE" ]; then
    echo "* Adding to or creating $runtime_mode named ${groupOrClusterName} and adding $serverName to it."
    createClusterOrGroupAddServer $runtime_mode $groupOrClusterName
    sleep 2
    echo "* Complete."
    echo
fi
targetId=$(getTargetId)
targetType=$(getTargetType)
echo "* targetId=${targetId}"
echo "* targetType=${targetId}"
echo

# Analytics
if [ "$ANALYTICS_ENABLED" = "true" ]; then
	echo "* Enabling API Analytics"
	while true;do
		targetStatus=$(getTargetStatus)
		echo "targetStatus: $targetStatus"
		[ "$targetStatus" == "RUNNING" ] && break
		sleep 5
	done
	echo
	enableAPIAnalytics || failer "Failed to enable API analytics"

	if [ "$ANALYTICS_ELK_ENABLED" = "true" ]; then
		enableAPIAnalyticsELK || failer "Failed to enable ELK API Analytics"
	fi
        if [ "$ANALYTICS_SPLUNK_ENABLED" = "true" ]; then
                enableAPIAnalyticsSplunk || failer "Failed to enable Splunk API Analytics"
        fi
fi



echo "* Post-Script Execution"
for pscript in $(find ${SCRIPTS_HOME}/post-scripts/ -type f -executable -name "*.sh" 2>&1); do
        echo " - Executing script: $pscript"
        . "$pscript" || { echo "Script: $pscript FAILED. Exit Code: $?"; exit 1;}
        echo
done
echo


echo "* deployApps Execution"
if [ "$APP_DEPLOY_FROM" != "UNSET" ]; then
	. ${SCRIPTS_HOME}/appDeploy.sh
else
	echo " APP_DEPLOY_FROM = $APP_DEPLOY_FROM"
	echo " Nothing to deploy. Skipping."
fi
echo


echo "Startup script end: $(date)"
echo

#keep this script process running to keep the container from exiting
AUTO_TAIL=${AUTO_TAIL:-true}
echo "* AUTO_TAIL = $AUTO_TAIL"
if [ $AUTO_TAIL = 'true' ]; then 

	echo "* Attaching to mule_ee.log to keep alive"
	echo
	echo '=============== mule_ee.log ==================='
	trap 'echo TRAPPED SIGTERM - INITIATING DE-REGISTRATION;/opt/scripts/containerShutdown.sh;exit $?' TERM SIGTERM
	while true;do
	        tail -f ${MULE_HOME}/logs/mule_ee.log &
		wait $!
	done
else
	echo "* NOT going to keep process open."
fi

echo
echo '==============================================='
echo " Mule Runtime Registration Script"
echo '================== END ========================'
