#!/bin/bash

# $1:server_tag, $2:server_name, $3:server_port

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
HOME="/var/www/WebPanel"

HOME=${HOME%/}
if [[ $HOME == "" ]]; then
	echo "Home directory can't be '/' itself."
	exit 1
fi

# Allow only root execution
if (( $(id -u) != 0 )); then
	echo "This script requires root privileges"
	exit 1
fi

SERVER_TAG=$(echo "$1" | tr '[A-Z]' '[a-z]')
SERVER_NAME=$(echo "$2" | tr '[A-Z]' '[a-z]')
SERVER_PORT="$3"

if ! $(echo "$SERVER_TAG" | grep -Pqs "^web\d{3}$"); then
	echo "SERVER_TAG ($SERVER_TAG) is invalid."
	exit 1
fi

if ! $(echo "$SERVER_NAME" | grep -Pqs "^([a-z0-9][-a-z0-9]*\.)+[a-z]+$"); then
	echo "SERVER_NAME ($SERVER_NAME) is invalid."
	exit 1
fi

if ! $(echo "$SERVER_PORT" | grep -Pqs "^\d+$"); then
	echo "SERVER_PORT ($SERVER_PORT) is invalid."
	exit 1
fi

## Disabling config files
# php-fpm
STATUS=$(\mv "/etc/php-fpm.d/settings/sites-enabled/$SERVER_TAG.conf" "/etc/php-fpm.d/settings/sites-enabled/$SERVER_TAG.conf.bak" 2>&1)
# nginx
STATUS=$(\mv "/etc/nginx/settings/sites-enabled/$SERVER_TAG.conf" "/etc/nginx/settings/sites-enabled/$SERVER_TAG.conf.bak" 2>&1)
# web
STATUS=$(\mv "$HOME/sites-enabled/$SERVER_TAG" "$HOME/sites-enabled/$SERVER_TAG.bak" 2>&1)

STATUS=$(sh "$SCRIPT_DIR/reload_servers.sh" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"

	exit 1
else
	STATUS=$(\rm -f "/etc/php-fpm.d/settings/sites-enabled/$SERVER_TAG.conf.bak" 2>&1)
	STATUS=$(\rm -f "/etc/nginx/settings/sites-enabled/$SERVER_TAG.conf.bak" 2>&1)
	STATUS=$(\rm -f "$HOME/sites-enabled/$SERVER_TAG.bak" 2>&1)
	
	STATUS=$(\rm -f "/etc/php-fpm.d/settings/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)
	STATUS=$(\rm -f "/etc/nginx/settings/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)
	STATUS=$(\rm -f "$HOME/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME" 2>&1)
fi

exit 0
