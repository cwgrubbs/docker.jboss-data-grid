#!/bin/bash

# Exit if an error is encountered
set -e

### Set defaults for any of the environment variables
set_defaults() {
    if [[ ! "${MODE}" ]]; then
        MODE="STANDALONE"
    fi

    if [[ ! "${JDG_USERNAME}" ]]; then
        JDG_USERNAME="user"
    fi

    if [[ ! "${JDG_PASSWORD}" ]]; then
        JDG_PASSWORD="user123!"
    fi
	
	if [[ ! "${JDG_ADMIN_USERNAME}" ]]; then
        JDG_ADMIN_USERNAME="admin"
    fi

    if [[ ! "${JDG_ADMIN_PASSWORD}" ]]; then
        JDG_ADMIN_PASSWORD="admin123!"
    fi
}

# Creates the options to be passed to the program that will start up jboss, facilitating variable replacement in the
# XML files
create_option_string() {
    OPTS="$OPTS"
    
    # set the host ip for eth0 - this may not scale well
    HOST_IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')

    OPTS="${OPTS} -Djboss.bind.address=${HOST_IP}"
    OPTS="${OPTS} -Djboss.bind.address.unsecure=${HOST_IP}"
    OPTS="${OPTS} -Djboss.bind.address.management=${HOST_IP}"

    echo "Created Option String: ${OPTS}"
}

### Create  User
create_user() {
echo "Adding users"
     ${JDG_HOME}/jboss-datagrid-7.3.1-server/bin/add-user.sh -m -u ${JDG_ADMIN_USERNAME} -p ${JDG_ADMIN_PASSWORD} -ro admin --silent
	 ${JDG_HOME}/jboss-datagrid-7.3.1-server/bin/add-user.sh -a -u ${JDG_USERNAME} -p ${JDG_PASSWORD} -ro user --silent
}

start_standalone() {

    create_option_string

    ${JDG_HOME}/jboss-datagrid-7.3.1-server/bin/standalone.sh -c standalone.xml ${OPTS}
	
}

add_cache() {
    echo "Adding Cache Store"

xmlstarlet ed --inplace \
-s "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']" -t elem -n "local-cache" -v "" \
-i "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']/*[local-name() = 'local-cache'][not(@*)]" -t attr -n "name" -v "CM_CACHE" \
-s "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']/*[local-name() = 'local-cache'][@name='CM_CACHE']" -t elem -n "persistence" -v "" \
-s "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']/*[local-name() = 'local-cache'][@name='CM_CACHE']/*[local-name() = 'persistence']" -t elem -n "file-store" -v "" \
-i "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']/*[local-name() = 'local-cache'][@name='CM_CACHE']/*[local-name() = 'persistence']/*[local-name() = 'file-store']" -t attr -n "path" -v "/files/" \
-i "/*[local-name() = 'server']/*[local-name() = 'profile']/*[local-name() = 'subsystem'][namespace-uri() = 'urn:infinispan:server:core:9.4']/*[local-name() = 'cache-container']/*[local-name() = 'local-cache'][@name='CM_CACHE']/*[local-name() = 'persistence']/*[local-name() = 'file-store']" -t attr -n "fetch-state" -v "true" \
${JDG_HOME}/jboss-datagrid-7.3.1-server/standalone/configuration/standalone.xml


}
set_defaults
#check_env_values
create_user
add_cache

case "${MODE}" in
    STANDALONE*)
        echo "Starting JBOSS Data Grid Server in STANDALONE mode"
        start_standalone
    ;;
    #DOMAIN_MASTER*)
    #    echo "Starting JBOSS Data Grid Server in DOMAIN mode as Domain Master"
    #    start_domain_master
    #;;
    #DOMAIN_SLAVE*)
    #    echo "Starting JBOSS Data Grid Server in DOMAIN mode as Domain Slave"
    #    start_domain_master
esac