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

## Deleting *enabled* config files
STATUS=$(sh "$SCRIPT_DIR/domaindis.sh" "$SERVER_TAG" "$SERVER_NAME" "$SERVER_PORT" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

## Deleting *available* config files
# php-fpm
STATUS=$(\rm -f "/etc/php-fpm.d/settings/sites-available/$SERVER_TAG.conf" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi
STATUS=$(\rm -f "/etc/php-fpm.d/settings/sites-available-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)

# nginx
STATUS=$(\rm -f "/etc/nginx/settings/sites-available/$SERVER_TAG.conf" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi
STATUS=$(\rm -f "/etc/nginx/settings/sites-available-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)

### TODO: DNS Server
##################### removing server_name from /etc/hosts
#SERVER_NAME_ESCAPED=$(sed 's/[\*\.&\/]/\\&/g' <<<"$SERVER_NAME")
#STATUS=$(sed -i -e"s/127.0.0.1 $SERVER_NAME_ESCAPED//" "/etc/hosts" 2>&1)

# deleting user
STATUS=$(userdel "$SERVER_TAG" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# setting owner to nobody
STATUS=$(chown -R nobody:apache "/var/www/WebPanel/sites-available/$SERVER_TAG" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
fi

##################### Reloading servers
STATUS=$(sh "$SCRIPT_DIR/reload_servers.sh" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
	exit 1
fi

exit 0
