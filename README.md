# mule-containerize

## Scripts and templates to easily containerize the Mule Runtime with Docker and Kubernetes.

#### 1. Seed `source` directory with JRE, Mule Runtime, and Mule License.

[Update source directory](https://raw.githubusercontent.com/zeelewis/mule-containerize/main/source/CONTENTS)

A ./source/seed.sh script is provided for seeding a generic JRE and Runtime from my S3 Bucket

If the JRE and Runtime are not seeded into the `source` directory, the Dockerfile will pull it in automatically.

#### 2. [Optional] Insert applicable files into apps, conf, pre-scripts, post-scripts directories 
     ./apps

Mule applications that will be copied into ${MULE_HOME}/apps for local deployment.

     ./conf

Files which will override ${MULE_HOME}/conf default files. Ex: wrapper.conf

     ./pre-scripts
     ./post-scripts

Scripts which will be run prior to or after the main body of the registration logic.
The script filename must end in .sh and not contain spaces.
The script must be executable.
The script contents must be valid shell/bash and NOT have explicit exit statement as they are sourced and not run in a sub-shell.
The script may override environmental variables so take care to only do so in intended circumstances.
The script failing will stop the registration process.

#### 3. Building the image:

`docker build -t mule4 .`

#### 4. Running the image:

`docker run -it --env-file=env-file.var mule4`

or 

```
docker run \
-e ANYPOINT_HOST='myanypointhost.com' \
-e orgName='Test Org' \
-e envName=Sandbox \
-e ANYPOINT_USERNAME=username \
-e ANYPOINT_PASSWORD=password123 \
-e MULE_LICENSE_B64='2+W35iUhD9liJH0rXcKOSAk2E5yx+HVOfJFyJZLJlZsas121ilcUK7DzF4uaSWBTqOu2ICmorp4fmsG2LL+f0Lcj0r0Dn07d4vmwkS/AsFTjEK6rqCttK35GnpQJu3xtq+EMaQOnbUeednot3GJTTRWH3Jvm+RqpHu3zRNIaJyf0R+1ycJnrcPXPJO8BPwZgnmN/OXAQfZb8McBXBp78YR9B33fO1dfsda12345uFts9EwoAdejy0thY79SSKyb9+vtxQj8BAQmF1eLlAuSlx52XV1W9FhQo1YfEj+tKsasdf1111aNfpE7PwZBxcQIYpxNTr+x+WMy8c37V0TDwegCaMTcE3Y6y8gC1bg5k3pqFqtHeJU65Ck0HxckOq63YhI0yGwRdIAtaqKUCLvJSyzpNb95bjrBlB41d14wKrdtXpgIkjJse/FYxsJuPEPmS+3VBdYw9V9j1RX436Lo2Ql4XVTxWSMD+roBVmRKwoe58+hkPPSxP12jMLmcCDNhKt6UNqOWjNlUbtElp4u8HM4EaoUp9Io3qCRm7c+yE6HJbB2lqMSEIuzXOFKMrzoPasdfsaVtQrPhEdvgNDkKexxnqFD3XOoqjtjTR0BhCWkUwEGpRQJkdNf1dnge8GSqlQX6YaGVj8K46AhTbQo7yPqEEYK10UU6Z34XWDx4uCnNRa4zWrS1SSh4ecCYcwWaRHf0ggYGQbezceIrMXv7tQWKQ7pTaRDN9bNp/bceYNvJYKyYolPeeSmqiTCV6VjH2dfepouC4PvfiY8/TdEyCsrXJnoaOlgGns00HlYZhzj' \
mule4
```
* The license used above is not valid. You will need to provide a valid mule license converted into base64 format. This can be done with`base64 -w0 license.lic` where license.lic is the mule license file. 

## Environment Variables

This image uses environment variables for configuration.

|Available variables     |Default value        | Required | Description                                         |
|------------------------|---------------------|--------|--------------------------------------------|
|`ANYPOINT_HOST`         |no default           |Yes 	|Anypoint hostname|
|`ANYPOINT_USERNAME`     |no default           |Yes\* 	|Login username for Anypoint Platform           |
|`ANYPOINT_PASSWORD`     |no default           |Yes\* 	|Login password for Anypoint Platform           |
|`ANYPOINT_CLIENT_ID`    |no default           |Yes\* 	|Client ID to use in lieu of username/password           |
|`ANYPOINT_CLIENT_SECRET`|no default           |Yes\* 	|Client Password to use in lieu of username/password           |
|`orgName`               |no default| Yes | Anypoint Organization name.  Ex: My Business   |
|`envName`               |no default           | Yes |Anypoint environment name. Ex: Sandbox          |
|`MULE_LICENSE_B64`      |no default           |Yes |Base64 encoded Mule license            |
|`ANYPOINT_PORT`         |443           |No |Port to communicate with the Anypoint Platform API         |
|`HOSTNAME`              |Random Docker hostname           |No |Overrides the HOSTNAME of the container and the resulting Runtime name in Runtime Manager      |
|`nodeStyle`             |NONE           |No |Sets the Runtime grouping. Must be one of `NONE`, `SERVER_GROUP`, `CLUSTER`        |
|`appName`               |no default |No |Mule runtime Application name. This influences the cluster/group name.  Unused if nodeStyle is `NONE`.           |
|`groupOrClusterName`    |${appName}-${runtime_mode}    |No |Runtime Cluster or Group name. Unused is nodeStyle is `NONE`.          |
|`PLATFORM_TYPE`                |Will auto-detect if not set to value           |No |`CLOUDHUB`, `GOVCLOUD`, and `PCE` have incompatible registration commands. If not explicitly set it will attempt to detect based on ANYPOINT_HOST.      |
|`AUTO_TAIL`             |true           	|No 	|If `true` the script will not exit upon completion but will instead tail ${MULE_HOME}/logs/mule_ee.log. Useful to preventing the container from exiting.      |
|`MULE_OPTS`             | no default           |No 	| Options to be appended to the mule executable. Ex: `-M-Dkey=value` |
|`CLUSTER_MULTICAST`	 | false           	|No 	| Enable Multicast mode when nodeStyle is CLUSTER. Must be either `true` or `false`. |
|`AMC_OPTS`	 	 | no default 		|No 	| Provide custom options to `amc_setup` command. Will interpret `$ANYPOINT_HOST` `$ANYPOINT_PORT` vars. Ex: `-D https://${ANYPOINT_HOST}:${ANYPOINT_PORT}/apigateway/css -A https://someurl/hybrid/api/v2` | 
|`JAVA_AUTO_TRUST`	 | true 		|No 	| Automatic importing of the Control Plane certificate into the Java TrustStore | 
|`SKIP_LICENSE`	 	 | false 		|No 	| Skip importing of a License | 

### Application Deployment Variables

This image is capable of auto-deployment of applications using a url or path. This is an alternative to building the application into the ./apps directory.

|Available variables     |Default value        | Required | Description                                         |
|------------------------|---------------------|--------|--------------------------------------------|
|`APP_DEPLOY_FROM`       |no default           |No	|Space separated list of `urls`, `file path`, or `directory path`. Ex: `https://myapprepo.com/myapp1.jar /opt/apps/myapp2.jar /opt/myappdir`|
|`APP_DEPLOY_STYLE`     |LOCAL           |No 	|How to deploy. Using either `LOCAL` (place jars into ${MULE_HOME}/apps/ or `MANAGED` (deploy through Anypoint Platform API).    |
|`APP_DEPLOY_NAME`     |Name of the .jar in `APP_DEPLOY_FROM`      |No 	|Will override the name of the applications deployed. Multiple apps will have a `-#` applied.  | 

### ELK and Splunk Analytics / Event Tracking 

Limited support for enabling the Elk and Splunk plugins 

|Available variables     |Default value        | Required | Description                                         |
|------------------------|---------------------|--------|--------------------------------------------|
|`ANALYTICS_ENABLED`     | auto-detect         |No	| Master toggle for Analytics behavior. Will automatically update the wrapper.conf with `-Danypoint.platform.analytics_enabled=true`. Automatically enabled if unset and required by sub-element e.g. `ANALYTICS_ELK_ENABLED`|
|`ANALYTICS_ELK_ENABLED`     |false           |No	| Enables the ELK Analytics plugin |
|`ANALYTICS_ELK_LOG_FILE`     |${MULE_HOME}/logs/analytics/api-analytics.log           |No	| ELK Log output file |
|`ANALYTICS_ELK_LOG_ARCHIVE_PATTERN`     |${MULE_HOME}/logs/analytics/api-analytics-%d{yyyy-dd-MM}-%i.log           |No	| Archive pattern for ELK log |
|`ANALYTICS_ELK_LOG_STREAM`     |true          |No	| Stream ELK log to container STDOUT |
|`ANALYTICS_SPLUNK_ENABLED`     |false          |No	| Enables the Splunk Analytics plugin |
|`ANALYTICS_SPLUNK_HOST `     |no default          |No	| Splunk host |
|`ANALYTICS_SPLUNK_PORT`     |8089          |No	| Splunk port |
|`ANALYTICS_SPLUNK_USER`     |empty string          |No	| Splunk user |
|`ANALYTICS_SPLUNK_PASSWORD`     |empty string          |No	| Splunk password |

### FIPS 

Enables FIPS compliancy. To use FIPS, Java must be configured with a [cryptographic provider](https://csrc.nist.rip/groups/STM/cmvp/documents/140-1/140val-all.htm)

|Available variables     |Default value        | Required | Description                                         |
|------------------------|---------------------|--------|--------------------------------------------|
|`FIPS_ENABLED`     | false         |No	| Enable FIPS in the wrapper.conf and the registration phase | 
|`FIPS_AUTOCONFIG_JAVA`     | false         |No	| **EXPERIMENTAL** Attempt to autoconfigure java to use Bouncy Castle FIPS140-2 Provider | 
