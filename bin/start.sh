#!/bin/bash
#
# Script for starting your Java App in PaaS / Docker environment
# Modified from the SC4 Nico's version. 
#
# Environments variables supported:
# 1. JAR_FILE - mandatory, the path to your application JAR file
# 2. JVM_MEM_ARGS - optional, JVM memory related agruments, e.g. Xmx/Xms. If not supply, will set Xmx=Xms=1/2 of allocated memory
# 3. JVM_ARGS - optional, custom non-memory related JVM arguments
# 4. PROGRAM_ARGS - optional, the argument pass to your application (e.g. for the main method)  
# 5. BASE_LOG_DIR - optional, the folder for logging.
# 6. SCRIPT_DEBUG - optional, set to "true" to print debug message for this script
# 7. GC_LOG - optional, set to "true" to enable GC log. Will keep max. 5 GC log, each of size 10M. The GC log will be put in the LOG Folder
# 8. DEFAULT_TRUSTSTORE - optional, by default is true. Set this value to false if you don't want to to use the default SSL store setting
# Notice:
# 1. If you run this script in a window docker host, you MUST specify the memory and CPU argument. Otherwise, the memory/CPU detection command will not works 
#    e.g. allocate 1 CPU and 1GB memory> docker --memory="1g" --cpus="1"
#
#
# ---------------------------------------------------------------------------------------------------------------------

export CATALINA_HOME=/usr/local/cloud

# ---------------------------------------------------------------------------------------------------------------------
# Debug the script or not. If there is something abnormal, you can turn on this env to see debug trace of this .sh
# ---------------------------------------------------------------------------------------------------------------------
if [ "${SCRIPT_DEBUG}" = "true" ]; then
	set -x
fi

# ---------------------------------------------------------------------------------------------------------------------
# check mandatory input
# ---------------------------------------------------------------------------------------------------------------------

if [ -z $JAR_FILE ]; then

	echo "Please supply the following environment variables:"
	echo "--------------------------------------------------------------------------------------------------------------------------------"
	echo "1. JAR_FILE - mandatory, the path to your application JAR file"
	echo "2. JVM_MEM_ARGS - optional, JVM memory related agruments, e.g. Xmx/Xms. If not supply, will set Xmx=Xms=1/2 of allocated memory"
	echo "3. JVM_ARGS - optional, non-memory related JVM arguments"
	echo "4. PROGRAM_ARGS - optional, the argument pass to your application (e.g. for the main method)"
	echo "5. BASE_LOG_DIR - optional, the folder for logging. This path should be SAME as the ALS log path. "
	echo "6. SCRIPT_DEBUG - optional, set to 'true' to print debug message for this script"
	echo "7. GC_LOG - optional, set to 'true' to enable GC log. Will keep max. 5 GC log, each wich size 10M"
	echo "8. DEFAULT_TRUSTSTORE - optional, by default is true. Set this value to false if you don't want to to use the default SSL store setting"
	echo "--------------------------------------------------------------------------------------------------------------------------------"
	echo "If you run this script in docker environment with Winddows host, you need to specify docker arguments for memory and CPU, e.g. --memory='1g' --cpus='1'. Otherwise, the CPU and memory detection will be failed."

	exit -1

fi

# ---------------------------------------------------------------------------------------------------------------------
# Logging directory setup (for CLAP and others logging)
# ---------------------------------------------------------------------------------------------------------------------

# set the default base log dir to '/logs'
if [ -z $BASE_LOG_DIR ]; then

	export BASE_LOG_DIR=/home/admin/cop-broker

fi

# check the hostname. in OpenShift, there will be a ENV 'HOSTNAME' set to the name of the POD.
if [ -z $HOSTNAME ]; then

	export HOSTNAME=`uname -n`

fi

# set the full path for logging
export LOG_DIR=${BASE_LOG_DIR}
echo "------------------------------------------------------------"
echo "Logging directory set to:" $LOG_DIR

# create log file directory if not exists
if [ ! -d $LOG_DIR ]; then
   mkdir -p $LOG_DIR

   if [ $? -ne 0 ]; then

       echo "Cannot create log dir: " $LOG_DIR

       exit -2

   fi

   echo "Create log directory: " $LOG_DIR
fi

# ---------------------------------------------------------------------------------------------------------------------
# JVM memory setup
# ---------------------------------------------------------------------------------------------------------------------

# Find the total memory allocated to the container in MB.
# If you need to customize the java heap size, you need to find the memory allocated

if [ ! -z $CLUSTER_SCALE_FLAG ]; then
    echo "------------------------------------------------------------"
    echo "CLUSTER_SCALE_FLAG = " $CLUSTER_SCALE_FLAG
    if [ $CLUSTER_SCALE_FLAG = "mini" ]; then
        export JVM_MEM_ARGS="-Xmx1g -Xms1g"
    elif [ $CLUSTER_SCALE_FLAG = "small" ]; then
        export JVM_MEM_ARGS="-Xmx2g -Xms2g"
    elif [ $CLUSTER_SCALE_FLAG = "standard" ]; then
        export JVM_MEM_ARGS="-Xmx4g -Xms4g"
    elif [ $CLUSTER_SCALE_FLAG = "large" ]; then
        export JVM_MEM_ARGS="-Xmx8g -Xms8g"
    fi
fi

# set the default memory setting if no memory JVM argument specified
# ref: https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/parallel.html#default_heap_size

if [ -z $JVM_MEM_ARGS ]; then

  TotalMemByte=`cat /sys/fs/cgroup/memory/memory.limit_in_bytes`
  UsageMemByte=`cat /sys/fs/cgroup/memory/memory.usage_in_bytes`
  MemByte=$[TotalMemByte-UsageMemByte]
  MemMB=$[MemByte/1024/1024]

  echo "------------------------------------------------------------"
  echo "Memory allocated to container: " ${MemMB}MB

	# set the default heap size = 1/2 of total memory allocated to the container
	# and set the initial heap size = max heap size to avoid heap resizing
	XMX=$[MemMB/2]
	XMS=$XMX
  testMemory=$TotalMemByte/1024/1024/1024
	if [ $testMemory -lt 512 ]; then
    export JVM_MEM_ARGS="-Xmx${XMX}m -Xms${XMS}m"

    echo "------------------------------------------------------------"
    echo "Use default JVM memory setting: " $JVM_MEM_ARGS

    # Specify the NewRatio if you need to tune the old/young generation size. Default young generation = 1/3 of heap size
    # ref: https://docs.oracle.com/javase/8/docs/technotes/guides/vm/gctuning/sizing.html
    #JVM_MEM_ARGS=$JVM_MEM_ARGS -XX:NewRatio=3

    # Specify the Metaspace (aka to PermGen Space of JDK7 or earlier)
    #JVM_MEM_ARGS=$JVM_MEM_ARGS XX:MaxMetaspaceSize=96m
	else
    echo "------------------------------------------------------------"
    echo "cat /sys/fs/cgroup/memory/memory.limit_in_bytes is too large: " $TotalMemByte
	fi

fi

# ---------------------------------------------------------------------------------------------------------------------
# JVM no of CPU checking. Can you uncomment script to find the CPU allocated to the container. You can tune the thread
# count (e.g. GC thread) if needed based on this value
# ---------------------------------------------------------------------------------------------------------------------
#cpu_quota=`cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us`
#cpu_period=`cat /sys/fs/cgroup/cpu/cpu.cfs_period_us`
#cpu=$[cpu_quota/cpu_period]


# ---------------------------------------------------------------------------------------------------------------------
# Enable JVM GC logging or not. If enabled, the log is put in the
# ---------------------------------------------------------------------------------------------------------------------
if [ "${GC_LOG}" = "true" ]; then

	export JVM_GC="-verbose:gc -Xloggc:${LOG_DIR}/${HOSTNAME}.gc.%t.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=10M -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCCause"
	echo "------------------------------------------------------------"
	echo "GC Log enabled. GC log file at: " ${LOG_DIR}/${HOSTNAME}.gc.%t.log
fi

# ---------------------------------------------------------------------------------------------------------------------
# Setup Java keystore for SSL connection
# ---------------------------------------------------------------------------------------------------------------------
if [ ! "${DEFAULT_TRUSTSTORE}" = "false" ]; then

	#export JVM_TRUSTSTORE="-Djavax.net.ssl.trustStore=/home/jboss/cacerts -Djavax.net.ssl.trustStorePassword=changeit"
	export JVM_TRUSTSTORE="-Djavax.net.ssl.trustStore=/usr/local/cloud/cacerts -Djavax.net.ssl.trustStorePassword=changeit"
	echo "------------------------------------------------------------"
	echo "SSL truststore setting: " $JVM_TRUSTSTORE

fi


# ---------------------------------------------------------------------------------------------------------------------
# Setup tomcat HTTP access log for CLAP. Make sure you adhere to the format specified for CLAP log ingestion
# 1. JSON format
# 2. filename = ${HOSTNAME}-yyyyMMdd-access-json.log
# ---------------------------------------------------------------------------------------------------------------------

export TOMCAT_HTTP_LOGGING="-Dserver.tomcat.accesslog.encoding=UTF-8 -Dserver.tomcat.accesslog.prefix=$HOSTNAME -Dserver.tomcat.accesslog.file-date-format=-yyyyMMdd -Dserver.tomcat.accesslog.suffix=-access-json.log -Dserver.tomcat.accesslog.directory=$LOG_DIR -Dserver.tomcat.accesslog.enabled=true -Dserver.tomcat.accesslog.pattern={\"x_forwarded_for\":\"%{X-Forwarded-For}i\",\"client_ip\":\"%h\",\"client_user\":\"%l\",\"authenticated\":\"%u\",\"request_time\":\"%{yyyy-MM-dd'T'HH:mm:ss.SSSZ}t\",\"request_url\":\"%r\",\"http_code\":\"%s\",\"send_bytes\":\"%b\",\"query_string\":\"%q\",\"http_referer\":\"%{Referer}i\",\"user_agent\":\"%{User-Agent}i\",\"request_time_ms\":\"%D\"}"

echo "------------------------------------------------------------"
echo "Tomcat HTTP access log dir: " $LOG_DIR

# ---------------------------------------------------------------------------------------------------------------------
# Setup JMX
# ---------------------------------------------------------------------------------------------------------------------
if [ ! -z $ENABLE_JMX ] && [ "${ENABLE_JMX}" = "true" ]; then
    HOSTNAME=`hostname -i`
    export JMX_SETTING="-Djava.rmi.server.hostname=${HOSTNAME} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=18999 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
    echo "------------------------------------------------------------"
    echo "Enabled JMX. "
    echo "JMX settings: " ${JMX_SETTING}
fi

# ---------------------------------------------------------------------------------------------------------------------
# Setup default file mask
# ---------------------------------------------------------------------------------------------------------------------

export UMASK=0022

echo "------------------------------------------------------------"
echo "Set file UMASK: $UMASK"

# ---------------------------------------------------------------------------------------------------------------------
# Finally, setup the full JVM argument to start your application
# ---------------------------------------------------------------------------------------------------------------------
SERVER_PORT_PARAM="--server.port=8080"
if [ $SERVER_PORT ] ; then
  SERVER_PORT_PARAM="--server.port="${SERVER_PORT}
fi


export PROGRAM_ARGS="$PROGRAM_ARGS $SERVER_PORT_PARAM "

echo "------------------------------------------------------------"
echo ""
echo "Application JAR file: " $JAR_FILE
echo ""
echo "Program argument: " $PROGRAM_ARGS


export JAVA_OPTS="-server $JMX_SETTING $JFR_SETTING $JVM_MEM_ARGS $JVM_GC \
-XX:+HeapDumpOnOutOfMemoryError \
-XX:HeapDumpPath=$LOG_DIR \
-Djava.awt.headless=true \
-Djava.security.egd=file:/dev/./urandom \
-Dfile.encoding=UTF-8  \
-XX:ErrorFile=${LOG_DIR}/${HOSTNAME}.hs_err.$(date +"%Y%m%d%H%M").log \
-XX:+CrashOnOutOfMemoryError \
$JVM_TRUSTSTORE $JVM_ARGS $TOMCAT_HTTP_LOGGING"

export JDK_JAVA_OPTIONS="${JAVA_OPTS}"

echo "------------------------------------------------------------"
echo "JVM options used:"
echo "------------------------------------------------------------"

for arg in $JAVA_OPTS
do
    echo ">> " $arg
done
echo "------------------------------------------------------------"


# ---------------------------------------------------------------------------------------------------------------------
# start the program
# ---------------------------------------------------------------------------------------------------------------------
java $JAVA_OPTS -jar $JAR_FILE $PROGRAM_ARGS

exit $?
