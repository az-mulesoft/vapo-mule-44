#!/usr/bin/bash
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

deployApps(){
		echo
		echo "* Deploying Apps"
		sleep 3 
		myServInfo="$(getServerInfo)"
		targetId="$(echo $myServInfo | jq -e .clusterId)" || targetId="$(echo $myServInfo | jq -e .serverGroupId)" || targetId="${serverId}"

		targetType="servers"
		echo $myServInfo | grep '.clusterId' >/dev/null 2>&1 && targetType="clusters" 
		echo $myServInfo | grep '.serverGroupId' >/dev/null 2>&1 && targetType="serverGroups" 
		echo "targetId: $targetId"
		echo "targetType: $targetType"
		echo "Waiting for targetStatus to show as RUNNING"
		echo
		sleep 2
		while true;do
			local targetStatus=$(getTargetInfo | jq '.status' | tr -d '"')
			echo "targetStatus: $targetStatus"
			[ "$targetStatus" == "RUNNING" ] && break
			sleep 5
		done
		echo

		deployURL="${hybridAPI}/applications"
		_APP_NUM=$(ls -1 ${_APP_PUT_TMP}/*.jar | wc -l)
		_APP_CUR_NUM=1
		for fileName in ${_APP_PUT_TMP}/*.jar; do
			echo "[${_APP_CUR_NUM}/${_APP_NUM}]"

			# If APP_DEPLOY_NAME isn't used then use the fileName
			if [ "$APP_DEPLOY_NAME" == "UNSET" ]; then
				_APP_NAME=$(basename -s .jar $fileName)
			else
				_APP_NAME="$APP_DEPLOY_NAME"
				if [ ${_APP_NUM} -gt 1 ]; then
					_APP_NAME="${_APP_NAME}-${_APP_CUR_NUM}"
				fi
			fi

			## Ensure App Name is alpha-number and "-" and 40 chars or less
			_APP_NAME=$(echo $_APP_NAME | tr -cd '[:alnum:]-' | cut -c 1-40)

			echo "	Deploying APP: ${_APP_NAME}"

			if [ "$APP_DEPLOY_STYLE" == "MANAGED" ];then
				echo "	deployStyle: Managed"
				echo "	hybridAPI: ${hybridAPI}"
				echo "	deployURL: ${deployURL}"
				echo "	fileName: $fileName"
				echo "	serverid: ${targetId}"
				echo "	Deploying..."
				sleep 2
				#echo POST "${deployURL}" \
				mycurloutput=$(curl  --write-out "%{http_code}" -sk -X POST "${deployURL}" \
					 -H "Authorization: Bearer ${accessToken}" \
					 -H "Cache-Control: no-cache" \
					 -H "Content-Type: multipart/form-data" \
					 -H "X-ANYPNT-ENV-ID: ${envId}" \
					 -H "X-ANYPNT-ORG-ID: ${orgId}" \
					 -F autoStart=true \
					 -F artifactName=${_APP_NAME} \
					 -F targetId=${targetId} \
					 -F file=@${fileName})
				_appDeployStatus="FAIL"
				# Successful POST will have a 202 code at the very end thanks to the --write-out option above.
				echo "$mycurloutput" | egrep '202$' >/dev/null && _appDeployStatus="SUCCESS"	
				echo "$mycurloutput"
				echo
			elif [ "$APP_DEPLOY_STYLE" == "LOCAL" ];then
				echo "	deployStyle: Local"
				echo "	Deploying..."
				mv $fileName ${MULE_HOME}/apps/ && _appDeployStatus="SUCCESS"
			fi
			echo "	Result: ${_appDeployStatus}"
			_APP_CUR_NUM=$(($_APP_CUR_NUM+1))
			echo
		done
		echo "* Removing files from ${_APP_PUT_TMP}"
		rm -f ${_APP_PUT_TMP}/*.jar
}


### START APP DEPLOYMENT ###

_APP_PUT_TMP='/tmp/apps'
rm -f ${_APP_PUT_TMP}/*
mkdir -p "$_APP_PUT_TMP"


echo
echo "========= BEGIN APP DEPLOYMENT ========="
echo "* Downloading Application file(s) to $_APP_PUT_TMP"
echo "APP_DEPLOY_FROM=[$APP_DEPLOY_FROM]"
echo

IFS=' ' read -r -a myarray <<< "$APP_DEPLOY_FROM"

for myindex in "${!myarray[@]}"
do
    myelem="${myarray[myindex]}"
    #echo "$myindex $myelem"

    echo
    myindexadd1=$(( $myindex + 1 ))
    echo -n "[${myindexadd1}/${#myarray[@]}]   "
    #HTTP 
    if echo $myelem | egrep '^http[s]*://'>/dev/null; then
	echo "URL: $myelem"
	STATUS_CODE=$(cd $_APP_PUT_TMP && curl --write-out "%{http_code}" -L -f -O -ks "$myelem")
	if [ $STATUS_CODE -ne 200 ]; then
		echo "   ! Download of $myelem failed. HTTP_CODE: $STATUS_CODE"
	fi
    #DIR
    elif [ -d "$myelem" ]; then
	echo "DIR: $myelem"
	for fileName in ${myelem}/*.jar; do
		echo -n "   - ${fileName}: "
	
		#If *.jar NOT 0 size then process
		if [ -s $fileName ];then 
			cp -p ${myelem}/*.jar "$_APP_PUT_TMP" && echo " OK" 
		else
			echo "   0 size   (NOT GRABBED!)"
			continue
		fi
	done
    #FILE
    elif [ -f "$myelem" ]; then
	echo "FILE: $myelem"
	if [ -s $myelem ];then 
			cp -p ${myelem} "$_APP_PUT_TMP" && echo " OK" 
		else
			echo "   0 size   (NOT GRABBED!)"
			continue
		fi
    #UNKNOWN
    else
	echo "UNKNOWN: $myelem (NOT GRABBED!)"
    fi
done

echo
echo "* CONTENTS OF $_APP_PUT_TMP"
ls -l "$_APP_PUT_TMP"

if ls ${_APP_PUT_TMP}/*.jar >/dev/null 2>&1; then
	deployApps
else
	echo "* No Apps to Deploy. Skipped."
fi
echo
echo "========= END APP DEPLOYMENT ========="
