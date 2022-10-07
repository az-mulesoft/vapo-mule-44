#!/bin/bash

## Fail if an unset variable is used.
#set -u

failer() {
  echo
  echo "======= FAILURE ======="
  echo -e "$1"
  echo "======= FAILURE ======="
  echo
  exit 1
}

contains() {
  string="$1"
  substring="$2"
  if test "${string#*$substring}" != "$string"
  then
  return 0    #$substring is in $string
  else
  return 1    #$substring is not in $string
  fi
}

setENV() {
  serverName="$HOSTNAME"
  ### use $ANYPOINT_PORT if it exists, otherwise set to 443 
  ANYPOINT_PORT="${ANYPOINT_PORT:-443}"

  ### Set MULE_LICENSE_B64 to empty string if not set. This is required for 'set -u' to not fail if the var is not set. 
  ### This is the base64 encoded Mule license. It's optinal as it's an alternative to baking in the license.lic to the image.
  MULE_LICENSE_B64=${MULE_LICENSE_B64:-}
  
  hybridAPI="https://$ANYPOINT_HOST/hybrid/api/v1"
  armuiAPI="https://$ANYPOINT_HOST/armui/api/v1"
  accAPI="https://$ANYPOINT_HOST/accounts"

  # Enables providing additional options to the default amc_setup command. Useful for govcloud integration or other non-standard deployments.
  AMC_OPTS="${AMC_OPTS:-}"
  # Interpret variables ex: ${ANYPOINT_HOST}
  AMC_OPTS="$(echo ${AMC_OPTS} | envsubst '$ANYPOINT_HOST,$ANYPOINT_PORT')"

  # Automatically import Control Plane cert into Java truststore by default.
  JAVA_AUTO_TRUST="${JAVA_AUTO_TRUST:-true}"
  # Skip importation of License.
  SKIP_LICENSE="${SKIP_LICENSE:-false}"

  ### Valid runtime_mode: NONE, CLUSTER, SERVER_GROUP
  #runtime_mode="${nodeStyle:-SERVER_GROUP}"
  runtime_mode="${nodeStyle:-NONE}"
  CLUSTER_MULTICAST="${CLUSTER_MULTICAST:-false}"

  ANYPOINT_CLIENT_ID="${ANYPOINT_CLIENT_ID:-UNSET}"
  ANYPOINT_CLIENT_SECRET="${ANYPOINT_CLIENT_SECRET:-UNSET}"
  CONNECTED_APP="false"
  if [ "$ANYPOINT_CLIENT_ID" != "UNSET" ]; then
	echo "* Client ID is set to: ${ANYPOINT_CLIENT_ID}"
	echo "* Enabling Connected App auth and disabling username/password."
	echo
	CONNECTED_APP="true"
	ANYPOINT_USERNAME="UNSET"
	ANYPOINT_PASSWORD="UNSET"
  fi


  ### instantiate MULE_OPTS to empty string if not already set. 
  MULE_OPTS="${MULE_OPTS:-}"

	
  
  ## Cluster naming
  if [ "$runtime_mode" = "NONE" ]; then
	  appName="${appName:-UNSET}"
  fi
  groupOrClusterName=${groupOrClusterName:-"$appName-$runtime_mode"}


  ### Control Automated App Deployment
  ## List of deployment files separated by spaces. Support urls, files, directories
  ## Ex: APP_DEPLOY_FROM:   https://myfileshare.com/myapp.jar /opt/myapps/specialapp.jar 
  APP_DEPLOY_FROM="${APP_DEPLOY_FROM:-UNSET}"
  ## APP_DEPLOY_STYLE: MANAGED (push apps through curl to controle plane) or LOCAL (copy to ${MULE_HOME}/apps/
  APP_DEPLOY_STYLE="${APP_DEPLOY_STYLE:-LOCAL}"
  ## Can optionally Name your deployed app(s). If more than one will have '-#' appended where '#' is the order of processing.
  ## If unset will default to the filename of the app (minus the .jar and non-alphanumeric characters)
  APP_DEPLOY_NAME="${APP_DEPLOY_NAME:-UNSET}"


  ## If ANYPOINT_HOST is set to cloudhub and IS_PCE is not set...
  PLATFORM_TYPE="${PLATFORM_TYPE:-UNSET}"
  ## IS_PCE determines the amc_setup command in registerMule.sh
  case ${PLATFORM_TYPE} in
	  "PCE"|"GOVCLOUD"|"CLOUDHUB")
		  echo "* PLATFORM_TYPE was manually set to ${PLATFORM_TYPE}"
		  ;;
	  "UNSET")
		  if [ "$ANYPOINT_HOST" = "anypoint.mulesoft.com" ]; then
			  echo "* Cloudhub Detected: ANYPOINT_HOST = $ANYPOINT_HOST"
			  echo "* Setting IS_PCE to false."
			  echo "* You may override this by explicitly setting PLATFORM_TYPE."
			  PLATFORM_TYPE='CLOUDHUB'
		  elif [ "$ANYPOINT_HOST" = "gov.anypoint.mulesoft.com" ]; then
			  echo "* Govcloud Detected: ANYPOINT_HOST = $ANYPOINT_HOST"
			  echo "* You may override this by explicitly setting PLATFORM_TYPE."
			  PLATFORM_TYPE='GOVCLOUD'
		  else
			  echo "* Cloudhub and Govcloud not Detected: ANYPOINT_HOST = $ANYPOINT_HOST"
			  echo "* Assuming it is PCE."
			  echo "* You may override this by explicitly setting PLATFORM_TYPE."
			  PLATFORM_TYPE='PCE'
		  fi
		  ;;
	   *)
	   	  failer "PLATFORM_TYPE if set must be set to one of: GOVCLOUD, PCE, CLOUDHUB"
		  ;;
  esac

   ##Analytics
  ANALYTICS_ENABLED="${ANALYTICS_ENABLED:-UNSET}"

  ANALYTICS_ELK_ENABLED="${ANALYTICS_ELK_ENABLED:-false}"
  ANALYTICS_SPLUNK_ENABLED="${ANALYTICS_SPLUNK_ENABLED:-false}"
  ANALYTICS_ELK_LOG_FILE=${ANALYTICS_ELK_LOG_FILE:-${MULE_HOME}/logs/analytics/api-analytics.log}
  ANALYTICS_ELK_LOG_ARCHIVE_PATTERN=${ANALYTICS_ELK_LOG_ARCHIVE_PATTERN:-$MULE_HOME/logs/analytics/api-analytics-%d{yyyy-dd-MM}-%i.log}
  ANALYTICS_ELK_LOG_STREAM=${ANALYTICS_ELK_LOG_STREAM:-true}

  ANALTYICS_SPLUNK_HOST="${ANALYTICS_SPLUNK_HOST:-UNSET}"
  ANALTYICS_SPLUNK_PORT="${ANALYTICS_SPLUNK_PORT:-8089}"
  ANALTYICS_SPLUNK_USER="${ANALYTICS_SPLUNK_USER:-}"
  ANALTYICS_SPLUNK_PASSWORD="${ANALYTICS_SPLUNK_PASSWORD:-}"
  # Unless set to false, enabled ANALYTICS_ENABLED if either ELK or Splunk is enabled.
  if ([ "$ANALYTICS_ELK_ENABLED" = "true" ] || [ "$ANALYTICS_SPLUNK_ENABLED" = "true" ]) && [ "$ANALYTICS_ENABLED" = "UNSET" ];then
        echo "* Analytics auto-enabled due ELK or Splunk. Explicitly set to 'false' to disable."
        ANALYTICS_ENABLED="true"
  else  
        echo "* Analytics automatically disabled."
        ANALYTICS_ENABLED="false"
  fi 


  # FIPS
  FIPS_ENABLED="${FIPS_ENABLED:-false}"
  FIPS_AUTOCONFIG_JAVA="${FIPS_AUTOCONFIG_JAVA:-false}"


  # Check all required variables. 
  for ovar in FIPS_ENABLED ANALYTICS_ENABLED ANALYTICS_ELK_ENABLED ANALYTICS_SPLUNK_ENABLED APP_DEPLOY_FROM APP_DEPLOY_STYLE CONNECTED_APP ANYPOINT_CLIENT_ID ANYPOINT_CLIENT_SECRET PLATFORM_TYPE MULE_HOME ANYPOINT_USERNAME ANYPOINT_PASSWORD orgName envName appName ANYPOINT_HOST ANYPOINT_PORT runtime_mode serverName groupOrClusterName hybridAPI armuiAPI accAPI; do
	  ## POSIX way to do indirect variable expansion. Alternative to ${!var} bash-ism.
          eval xvar=\"\$$ovar\"
          if [ -n "${xvar}" ] ; then
		  if [ "$ovar" == "ANYPOINT_PASSWORD" ]; then
			  echo "  $ovar == **********"
			 # echo "  $ovar == $xvar"
		  elif [ "$ovar" == "ANYPOINT_CLIENT_SECRET" ]; then
			  echo "  $ovar == **********"
                  elif [ "$ovar" == "ANALYTICS_SPLUNK_PASSWORD" ]; then
                          echo "  $ovar == **********"
		  else
			  echo "  $ovar == $xvar"
		  fi
          else
                  echo "  FAIL: $ovar is not set!"
                  exit 1
		  #return 1
		  # Should probably return 1 and then let calling script check and exit, but this is easier.
          fi
  done

  echo
  echo
  echo
  echo "* Testing Connection to: ${ANYPOINT_HOST}:${ANYPOINT_PORT}"
  timeout 3 bash -c "cat < /dev/null > /dev/tcp/${ANYPOINT_HOST}/${ANYPOINT_PORT}" || failer "Could not connect to $ANYPOINT_HOST"
  echo "* Success"
  echo


  echo
  echo "* Getting accessToken"
  accessToken=$(getAPIToken) || failer "Function getAPIToken failed to retrieve accessToken."
  echo "accessToken=$accessToken"

  echo
  echo "* Getting orgId"
  orgId=$(getOrgId) || failer "Function getOrgId failed to retrieve orgId."
  echo "orgId=$orgId"
  echo 

  echo "* Getting envId"
  envId=$(getEnvId) || failer "Function getEnvId failed to retrieve envId."
  echo "envId=$envId"
  echo

  echo "* Getting amcToken"
  amcToken=$(getRegistrationToken) || failer "Function getRegistrationToken failed to retrieve amcToken."
  echo "amcToken=$amcToken"
  echo

  echo "* Getting serverIp"
  serverIp=$(getServerIp) || failer "Function getServerIp failed to retrieve serverIp."
  echo "serverIp=$serverIp"
  echo
}


# Authenticate with user credentials (Note the APIs will NOT authorize for tokens received from the OAuth call. A user credentials is essential)
getAPIToken() {
  #echo $(curl -k $accAPI/login -X POST -d "username=$ANYPOINT_USERNAME&password=$ANYPOINT_PASSWORD" | jq --raw-output .access_token)
  if [ "$CONNECTED_APP" == "true" ]; then
	  xret=$(curl -sk "${accAPI}/api/v2/oauth2/token" -X POST -H "Content-Type: application/json" \
                 -d "{\"grant_type\": \"client_credentials\", \"client_id\": \"${ANYPOINT_CLIENT_ID}\", \"client_secret\": \"${ANYPOINT_CLIENT_SECRET}\"}" |\
		 jq -e --raw-output .access_token)
  else
	  xret=$(curl -sk ${accAPI}/login -X POST -d "username=$ANYPOINT_USERNAME&password=$ANYPOINT_PASSWORD" 2>/dev/null | jq -e --raw-output .access_token)
  fi

  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Convert org name to ID
getOrgId() {
  jqParam=".user.contributorOfOrganizations[] | select(.name==\"$orgName\").id"
  xret=$(curl -ks $accAPI/api/me -H "Authorization:Bearer $accessToken" | jq -e --raw-output "$jqParam")
  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Convert environment name to ID
getEnvId() {
  jqParam=".data[] | select(.name==\"$envName\").id"
  xret=$(curl -ks $accAPI/api/organizations/$orgId/environments -H "Authorization:Bearer $accessToken" | jq -e --raw-output "$jqParam")
  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Get AMC server registration token
getRegistrationToken() {
  xret=$(curl -ks $hybridAPI/servers/registrationToken -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq -e --raw-output .data)
  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Get Server ID
getServerId() {
  jqParam=".data[] | select(.name==\"$serverName\").id"
  xret=$(getServerData | jq -e --raw-output "$jqParam" )
  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Get Server Status 
getServerStatus() {
  jqParam=".data[] | select(.name==\"$serverName\").status"
  xret=$(getServerData | jq -e --raw-output "$jqParam" )
  if [ "$?" -eq 0 ]; then
	  echo "$xret"
	  return 0
  else
	  return 1
  fi
}

# Get Data for _ALL_ Servers
getServerData(){
	xret=$(curl -ks $hybridAPI/servers/ -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
	if [ "$?" -eq 0 ]; then
		echo "$xret"
		return 0
	else
		return 1
	fi
}


# Get Server IP
getServerIp() {
  echo $(hostname -i)
}

# Create app-specific wrapper-custom properties file
generateCustomWrapperPropsFile() {
  touch $MULE_HOME/conf/wrapper-custom.conf
  echo "#encoding=UTF-8" >> $MULE_HOME/conf/wrapper-custom.conf
  echo -e "-Danypoint.platform.client_id=$ANYPOINT_CLIENTID\n" >> $MULE_HOME/conf/wrapper-custom.conf
  echo -e "-Danypoint.platform.client_secret=$ANYPOINT_CLIENTSECRET\n" >> $MULE_HOME/conf/wrapper-custom.conf
  echo "$MULE_VARS" >> $MULE_HOME/conf/wrapper-custom.conf
}

# $1 = cluster or serverGroup
# $2 = cluster or group name
# $3 = cluster or group ID
addServerToClusterOrGroup() {
     # epoch miliseconds
     epochmseconds=$(($(date +%s%N)/1000000))
     clusterOrGroupId=$3

     # check if server already added, not expected
     server=$(curl -ks $armuiAPI/servers?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\").details"
     member=$(echo $server | jq --raw-output "$jqparam" | grep name | grep $serverName)
     if [ "$member" != "" ]; then
        echo "$(date +%Y-%m-%dT%T) - Server $serverName ($serverId) - has already been added to Cluster or Server Group: $2"
        return
     fi

     # Add the server to the requested cluster or server group
     #if [[ "$1" == "CLUSTER" ]]; then    # add server to cluster
     if [ "$1" = "CLUSTER" ]; then    # add server to cluster
        uri="clusters/$clusterOrGroupId/servers"
        data="{\"serverId\":$serverId,\"serverIp\":\"$serverIp\"}"
     #elif [[ "$1" == "SERVER_GROUP" ]]; then
     elif [ "$1" = "SERVER_GROUP" ]; then
        uri="serverGroups/$clusterOrGroupId/servers/$serverId"
        data="{\"serveGroupId\":$clusterOrGroupId,\"serverId\":$serverId}"
     fi
     curl -ksf -X "POST" $hybridAPI/$uri?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H "Content-Type: application/json" -d "$data"
     #if [[ $? != 0 ]]; then
     if [ "$?" -ne 0 ]; then
        echo "$(date +%Y-%m-%dT%T) Adding the server to $2 ***** FAILED *****"
        return
     fi
     echo "$(date +%Y-%m-%dT%T) Server $serverName was added to $2"
}

checkClusterGroup() {
     server=$(curl -ks $hybridAPI/$1 -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
     jqparam=".data[] | select(.name==\"$2\").id"
     clusterId=$(echo $server | jq "$jqparam")
     echo $clusterId
}

createClusterOrGroupAddServer() {
   # epoch miliseconds
   epochmseconds=$(($(date +%s%N)/1000000))

   if [ "$1" = "CLUSTER" ]; then
      data="{\"name\":\"$2\",\"multicastEnabled\":${CLUSTER_MULTICAST},\"servers\":[{\"serverId\":$serverId,\"serverIp\":\"$serverIp\"}]}"
      cgType="clusters"
   elif [ "$1" = "SERVER_GROUP" ]; then
      data="{\"name\":\"$2\",\"serverIds\":[$serverId]}"
      cgType="serverGroups"
   else
      return
   fi

   url="$hybridAPI/$cgType?_=$epochmseconds"
   clusterGroupFound=$(checkClusterGroup $cgType $2)

   if [ "$clusterGroupFound" != "" ]; then     # Exisitng cluster or group
      echo "$(date +%Y-%m-%dT%T) - Cluster or Group: $1 exists"
      addServerToClusterOrGroup $1 $2 $clusterGroupFound
   else                                       # Create cluster or server, add server with cluster creation
      echo "Cluster/Group does not exist. Creating..."
      clusterGroupFound=""
      while true
      do
         curl -ksf -X "POST" $url -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" -H 'Content-Type: application/json' -d "$data"
         if [ "$?" -eq 0 ]; then
	    echo
            echo "$(date +%Y-%m-%dT%T) - $2 cluster or server group creation succeeded"
            return
         else
            clusterGroupFound=$(checkClusterGroup $cgType $2)
            [ "$clusterGroupFound" != "" ] && break
            sleep 5
         fi
      done
      addServerToClusterOrGroup $1 $2 $clusterGroupFound
   fi
}

##################################################################################################################
# Delete a cluster or server group
# Method: DELETE
deleteClusterGroup() {
   curl -ksf -X "DELETE" $hybridAPI/$2/"$1"?_="$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
   [ "$?" != 0 ] && echo "$(date +%Y-%m-%dT%T) - Error deleting $2 $1" || return 0
}

###################################################################################################################
# Delete server from cluster or server group
# Delete cluster or server group if no more servers left -- this may be a noise since pods get deleted/replaced
# at times causing cluster or server group to be recreated
#
# Request payload: None
# Method: DELETE

deleteServerFromClusterOrGroup() {
  epochmseconds=$(($(date +%s%N)/1000000))

  # Get cluster of server group
  servers=$(curl -skf $armuiAPI/servers?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken")
  echo $servers
  [ "$?" != 0 ] &&  echo "$(date +%Y-%m-%dT%T) - Error getting list of servers, clusters and-or server groups" && return


  # cluster/server group id
  jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\").id"
  clusterGroupId=$(echo $servers | jq "$jqparam")

  #echo ">>>> $epochmseconds, $envId, $orgId, $accessToken, $servers, $clusterGroupId <<<<"

  # if server belongs to cluster or server group
  jqparam=".data[] | select(.type==\"$1\" and .name==\"$2\") | .details | .servers[] | select(.name==\"$serverName\").name"
  server=$(echo $servers | jq "$jqparam")        # if server=null, do nothing and return
  [ -z $server ] && return

  # Remove server from cluster or server group
  [ "$1" = "CLUSTER" ] && type="clusters" || type="serverGroups"

  # delete server group or cluster if the last server in the cluster or group
  # a if not, just delete the server from the cluster or group

  jqParam=".data[] | select(.type==\"$1\" and .name==\"$2\").details.servers[].name"
  countServers=$(echo $servers | jq --raw-output "$jqParam" | wc -l)
  serverRemaining=$(echo $servers | jq --raw-output "$jqParam")

  if [ $((countServers)) -gt 1 ]; then
     curl -skf -X "DELETE" $hybridAPI/$type/$clusterGroupId/servers/"$serverId"?_"$epochmseconds" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
     if [ ! $? ]; then
        echo "$(date +%Y-%m-%dT%T) - Error removing server from $1 $2."
     fi
  else
     if [ "$serverName" = "$serverRemaining" ]; then
        # remove cluster or server group
        deleteClusterGroup $clusterGroupId $type
        [ ! $? ] && echo "$(date +%Y-%m-%dT%T) - Error deleting cluster: $2" && return
     fi
 fi
}

getServerGroupOrClusterName() {
	runtime_mode=''
	allServerData=$(getServerData)
	#getServerData | jq ".data[] | select(.id==$serverId).clusterName"
	#getServerData | jq ".data[] | select(.id==$serverId).serverGroupName"

	echo $allServerData | jq ".data[] | select(.id==$serverId).clusterName" 
	echo $allServerData | jq ".data[] | select(.id==$serverId).serverGroupName" 
	GroupOrClusterName=$(getServerData | jq -e --raw-output ".data[] | select(.id==$serverId) | .clusterName, .serverGroupName" | grep -v '^null$') || return $?
	echo "$GroupOrClusterName" && return
}

unregisterServer() {
	curl -ks -X "DELETE" "$hybridAPI/servers/$serverId" -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken"
}

getServerInfo() {
        local serverId=${1:-$serverId}
        xret=$(curl -ks $hybridAPI/servers/${serverId} -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq '.[]')
        echo $xret
}

getTargetInfo() {
        local mytargettype=${1:-$targetType}
        local mytargetid=${2:-$targetId}
        xret=$(curl -ks $hybridAPI/${mytargettype}/${mytargetid} -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq '.[]')
        echo $xret
}

getTargetId(){
	local myServInfo="$(getServerInfo)"
	local targetId=''
	targetId="$(echo $myServInfo | jq -e .clusterId 2>/dev/null)" || \
	targetId="$(echo $myServInfo | jq -e .serverGroupId 2>/dev/null)" || \
	targetId="$(getServerId)"
	echo "${targetId}"
}

getTargetType(){
	local myServInfo="$(getServerInfo)"
	local targetType="servers"
	echo $myServInfo | grep '.clusterId' >/dev/null 2>&1 && targetType="clusters"
	echo $myServInfo | grep '.serverGroupId' >/dev/null 2>&1 && targetType="serverGroups"
	echo "$targetType"
}

getTargetStatus(){
	getTargetInfo | jq '.status' | tr -d '"'
}


enableAPIAnalytics(){
	echo
	echo "* Enabling API Analytics"
	targetId="$(getTargetId)" || failer "Could not get targetId in $FUNCNAME"

	echo "* Getting Analytics componentId"
	componentId=$(curl -ks $hybridAPI/targets/$targetId/components/  -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq ".data[] | .component | select(.name==\"mule.agent.gw.http.service\").id")
	echo "* componentId = ${componentId}"

	echo "* Enabling Analytics"
	epochmseconds=$(($(date +%s%N)/1000000))
	read -d '' -r _PAYLOAD << ENDPAYLOAD
{
	"enabled":"true"
}
ENDPAYLOAD

	echo "* API Analytics Payload:"
	echo "$_PAYLOAD" #| jq
	echo

	_PATCHOUTPUT=$(\
	curl -ks --fail -X PATCH $hybridAPI/targets/$targetId/components/$componentId \
	-H "X-ANYPNT-ENV-ID:$envId" \
	-H "X-ANYPNT-ORG-ID:$orgId" \
	-H "Authorization:Bearer $accessToken" \
	-H "Content-Type: application/json" \
	-d "$_PAYLOAD") 
	rcode=$?

	echo "* API Return:"
	echo "$_PATCHOUTPUT" | jq '.'
	echo "$_PATCHOUTPUT" | jq '.data.enabled' | grep true >/dev/null 2>/dev/null || rcode=1 

	if [ $rcode -eq 0 ]; then
		echo "* Succecssfully enabled API Analytics"
	else
		echo "* FAILED enabling API Analytics"
	fi

	return $rcode
}

enableAPIAnalyticsELK(){
	echo
	echo "* Enabling ELK"
	echo "* Getting ELK componentId"
	targetId="$(getTargetId)"
	componentId=$(curl -ks $hybridAPI/targets/$targetId/components/  -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq ".data[] | .component | select(.name==\"mule.agent.gw.http.handler.log\").id")
	echo "* componentId = ${componentId}"
	epochmseconds=$(($(date +%s%N)/1000000))

        mkdir -p $(dirname $ANALYTICS_ELK_LOG_FILE) || { echo "$FUNCNAME could not create directory structure for $ANALYTICS_ELK_LOG_FILE"; return 1; }
        touch $ANALYTICS_ELK_LOG_FILE || { echo "$FUNCNAME could not create $ANALYTICS_ELK_LOG_FILE"; return 1; }
        ## PAYLOAD
        read -d '' -r _PAYLOAD << ENDPAYLOAD
{
  "enabled": true,
  "configuration": {
    "fileName": "${ANALYTICS_ELK_LOG_FILE}",
    "daysTrigger": 1,
    "mbTrigger": 100,
    "filePattern": "$MULE_HOME/logs/analytics/api-analytics-%d{yyyy-dd-MM}-%i.log",
    "immediateFlush": true,
    "bufferSize": 262144,
    "dateFormatPattern": "yyyy-MM-dd'T'HH:mm:ssSZ"
  }
}
ENDPAYLOAD

	echo "* ELK Payload:"
	echo "$_PAYLOAD"

	_PATCHOUTPUT=$(\
	curl -ks --silent -X PATCH \
	$hybridAPI/targets/$targetId/components/$componentId?_="$epochmseconds" \
	-H "X-ANYPNT-ENV-ID:$envId" \
	-H "X-ANYPNT-ORG-ID:$orgId" \
	-H "Authorization:Bearer $accessToken" \
	-H "Content-Type: application/json" \
	-d "$_PAYLOAD") 
	rcode=$?

	echo "* ELK Return:"
	echo "$_PATCHOUTPUT" | jq '.'
	echo "$_PATCHOUTPUT" | jq '.data.enabled' | grep true >/dev/null 2>/dev/null || rcode=1 

        if [ $rcode -eq 0 ]; then
                echo "* Succecssfully enabled ELK API Analytics"
                if [ "$ANALYTICS_ELK_LOG_STREAM" = "true" ]; then
                        echo "* Attaching ${ANALYTICS_ELK_LOG_FILE} stream to pid 1 STDOUT."
                        tail -F ${ANALYTICS_ELK_LOG_FILE} >> /proc/1/fd/1 &
                fi
        else
                echo "* FAILED enabling ELK API Analytics"
        fi
        echo

        return $rcode
}

enableAPIAnalyticsSplunk(){
        echo
        echo "* Getting Splunk componentId"
        targetId="$(getTargetId)"
        componentId=$(curl -ks $hybridAPI/targets/$targetId/components/  -H "X-ANYPNT-ENV-ID:$envId" -H "X-ANYPNT-ORG-ID:$orgId" -H "Authorization:Bearer $accessToken" | jq ".data[] | .component | select(.name==\"mule.agent.gw.http.handler.splunk\").id")
        echo "* componentId = ${componentId}"
        echo "* Enabling Splunk"
        epochmseconds=$(($(date +%s%N)/1000000))

        ## PAYLOAD
        read -d '' -r _PAYLOAD << ENDPAYLOAD
{
        "enabled":true, 
        "configuration":{                "dateFormatPattern":"yyyy-MM-dd'T'HH:mm:ssSZ",
                "splunkSource":"mule-gw-http-events",
                "endpointType":"rest-api",
                "scheme":"https",
                "port":${ANALYTICS_SPLUNK_PORT},
                "pass":"${ANALYTICS_SPLUNK_PASSWORD}",
                "host":"${ANALYTICS_SPLUNK_HOST}",
                "sslSecurityProtocol":"TLSv1_2",
                "user":"${ANALYTICS_SPLUNK_USER}",
                "splunkSourceType":"mule",
                "splunkIndexName":"main"
        }
}
ENDPAYLOAD

        echo "* Splunk Payload:"
        echo "$_PAYLOAD"

        _PATCHOUTPUT=$(\
        curl -ks --silent -X PATCH \
        $hybridAPI/targets/$targetId/components/$componentId?_="$epochmseconds" \
        -H "X-ANYPNT-ENV-ID:$envId" \
        -H "X-ANYPNT-ORG-ID:$orgId" \
        -H "Authorization:Bearer $accessToken" \
        -H "Content-Type: application/json" \
        -d "$_PAYLOAD")
        rcode=$?

        echo "* Splunk Return:"
        echo "$_PATCHOUTPUT" | jq '.'
        echo "$_PATCHOUTPUT" | jq '.data.enabled' | grep true >/dev/null 2>/dev/null || rcode=1

        if [ $rcode -eq 0 ]; then
                echo "* Succecssfully enabled Splunk API Analytics"
        else
                echo "* FAILED enabling Splunk API Analytics"
        fi
        echo

        return $rcode
}

## wrapperConfAddAdditional "-Danypoint.platform.analytics_enabled=true"
## Will add a new "wrapper.java.additional.NN" and increment NN
## Should only be called by wrapperConfSetAdditional and not directly itself.
wrapperConfAddAdditional(){
	if [ $# -eq 0 ]; then
	    echo "Error: $FUNCNAME requires arguments." 
	    return 1
	fi
	local MULE_CONF="${MULE_HOME}/conf/wrapper.conf"
	local curNum
	local newNum
	curNum=$(grep -ho '^wrapper\.java\.additional\.[0-9]*' ${MULE_CONF} | grep -o '[0-9]*$' | sort -n | tail -1)	

	for inputOption in "$@"
	do
		newNum=$(( $curNum + 1 ))
		local addLine="wrapper.java.additional.${newNum}=${inputOption}"
		echo "$addLine" >> ${MULE_CONF}
		echo "* $FUNCNAME appended [  $addLine  ] to ${MULE_CONF}"
		curNum=$newNum
	done
}

## wrapperConfSetAdditional "-Danypoint.platform.analytics_enabled=true" "-Danypoint.platform.fips_enabled=false"
## Smart add to wrapper.conf.
## Will either check, add new, or modify existing 'wrapper.java.additional' entry to wrapper.conf
wrapperConfSetAdditional(){
	if [ $# -eq 0 ]; then
	    echo "Error: $FUNCNAME requires arguments." 
	    return 1
	fi
	local MULE_CONF="${MULE_HOME}/conf/wrapper.conf"
	local inputOption="$1"

	for inputOption in "$@"
	do
		local _key=$(echo $inputOption | cut -f1 -d'=')
		local _value=$(echo $inputOption | cut -f2 -d'=')

		if grep "^wrapper\.java\.additional\.[0-9]*\=${_key}\=${_value}$" $MULE_CONF >/dev/null 2>/dev/null;then
			echo "* $FUNCNAME [ $_key=$_value ] already set ${MULE_CONF}. Skipped." 
			echo "	$(grep -- $_key $MULE_CONF | grep -v '^#')" 
		elif grep "^wrapper\.java\.additional\.[0-9]*\=${_key}\=" $MULE_CONF 2>/dev/null >/dev/null;then
			_old_value=$(grep "^wrapper\.java\.additional\.[0-9]*\=${_key}\=" $MULE_CONF | grep -o -- "${_key}\=.*" | cut -d'=' -f2) 
			sed -i "s/^\(wrapper.*=$_key=\).*$/\1$_value/g" $MULE_CONF
			echo "* $FUNCNAME [ $_key ] updated from [ $_old_value ] to [ $_value ] in $MULE_CONF"
			echo "	$(grep -- $_key $MULE_CONF | grep -v '^#')" 
		else
			echo "* $FUNCNAME [ $_key ] not in $MULE_CONF. Attempting to add..."
			wrapperConfAddAdditional "${_key}=${_value}"
		fi
	done
	echo
}
