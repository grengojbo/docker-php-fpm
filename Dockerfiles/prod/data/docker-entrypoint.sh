#!/usr/bin/env bash

set -e
set -u
set -o pipefail


###
### Globals
###

# The following global variables are available by our Dockerfile itself:
#   MY_USER
#   MY_GROUP
#   MY_UID
#   MY_GID

# Path to scripts to source
DVL_CONFIG_DIR="/docker-entrypoint.d"

# php.ini.d directory
DVL_PHP_INI_DIR="/usr/local/etc/php/conf.d"

# php-fpm conf.d directory
DVL_PHP_FPM_DIR="/usr/local/etc/php-fpm.d"

# This file holds error and access log definitions
DVL_PHP_FPM_CONF_LOGFILE="${DVL_PHP_FPM_DIR}/zzz-entrypoint-logfiles.conf"
DVL_PHP_INI_CONF_LOGFILE="${DVL_PHP_INI_DIR}/zzz-entrypoint-logfiles.ini"

# PHP-FPM log dir
DVL_FPM_LOG_DIR="/var/log/php"

# Custom ini dir (to be copied to actual ini dir)
DVL_PHP_CUST_INI_DIR="/etc/php-custom.d"

# Custom PHP-FPM dir (to be copied to actual FPM conf dir)
DVL_PHP_CUST_FPM_DIR="/etc/php-fpm-custom.d"

# Supervisord config directory
DVL_SUPERVISOR_CONFD="/etc/supervisor/conf.d"


###
### Source libs
###
init="$( find "${DVL_CONFIG_DIR}" -name '*.sh' -type f | sort -u )"
for f in ${init}; do
	# shellcheck disable=SC1090
	. "${f}"
done



#############################################################
## Entry Point
#############################################################

###
### Set Debug level
###
DEBUG_LEVEL="$( env_get "DEBUG_ENTRYPOINT" "0" )"
log "info" "Debug level: ${DEBUG_LEVEL}" "${DEBUG_LEVEL}"


###
### Change uid/gid
###
set_uid "NEW_UID" "${MY_USER}"  "/home/${MY_USER}" "${DEBUG_LEVEL}"
set_gid "NEW_GID" "${MY_GROUP}" "/home/${MY_USER}" "${DEBUG_LEVEL}"


###
### Set timezone
###
set_timezone "TIMEZONE" "${DVL_PHP_INI_DIR}" "${DEBUG_LEVEL}"


###
### PHP-FPM 5.2 and PHP-FPM 5.3 Env variables fix
###
if php -v 2>/dev/null | grep -Eoq '^PHP[[:space:]]5\.(2|3)'; then
	set_env_php_fpm "/usr/local/etc/php-fpm.d/env.conf"
fi


###
### Set Logging
###
set_docker_logs \
	"DOCKER_LOGS" \
	"${DVL_FPM_LOG_DIR}" \
	"${DVL_PHP_FPM_CONF_LOGFILE}" \
	"${DVL_PHP_INI_CONF_LOGFILE}" \
	"${MY_USER}" \
	"${MY_GROUP}" \
	"${DEBUG_LEVEL}"


###
### Validate socat port forwards
###
if ! port_forward_validate "FORWARD_PORTS_TO_LOCALHOST" "${DEBUG_LEVEL}"; then
	exit 1
fi


###
### Copy custom *.ini files
###
copy_ini_files "${DVL_PHP_CUST_INI_DIR}" "${DVL_PHP_INI_DIR}" "${DEBUG_LEVEL}"


###
### Copy custom PHP-FPM *.conf files
###
if [ "${PHP_VERSION}" = "5.2" ]; then
	copy_fpm_5_2_conf_file "${DVL_PHP_CUST_FPM_DIR}/php-fpm.xml" "${DEBUG_LEVEL}"
else
	copy_fpm_files "${DVL_PHP_CUST_FPM_DIR}" "${DVL_PHP_FPM_DIR}" "${DEBUG_LEVEL}"
fi


###
### Enable PHP Modules
###
enable_modules "ENABLE_MODULES" "${DEBUG_LEVEL}"


###
### Disable PHP Modules
###
disable_modules "DISABLE_MODULES" "${DEBUG_LEVEL}"


###
### Run custom user supplied scripts
###
execute_custom_scripts "/startup.1.d" "${DEBUG_LEVEL}"
execute_custom_scripts "/startup.2.d" "${DEBUG_LEVEL}"


###
###
### Startup
###
log "info" "Starting php-fpm" "${DEBUG_LEVEL}"
exec "${@}"
