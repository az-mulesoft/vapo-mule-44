#!/usr/bin/env sh
dljre(){
	echo "seed.sh: Downloading jre"
	curl -k -L -o jre-8u271-linux-x64.tar.gz 'https://www.dropbox.com/s/2rlyap6kg1lpius/jre-8u271-linux-x64.tar.gz'
}

dlmule(){
	echo "seed.sh: Downloading mule"
	#curl -k -L -o mule-ee-distribution-standalone-4.3.0.zip 'https://www.dropbox.com/s/80leoct3v4nf2d7/mule-ee-distribution-standalone-4.3.0-agent-2.4.14.zip'
	curl -k -L -o mule-ee-distribution-standalone-4.3.0.zip 'https://zlewis-temp.s3.us-east-2.amazonaws.com/mule-ee-distribution-standalone-4.3.0-agent-2.4.15-febpatch.zip'
}


if [ "$1" = "mule" ];then
	dlmule
elif [ "$1" = "jre" ];then
	dljre
else
	dlmule
	dljre
fi
