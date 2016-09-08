#!/bin/bash

# $1:server_tag

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
WEB_ROOT_DIR="web"
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

if ! $(echo "$SERVER_TAG" | grep -Pqs "^web\d{3}$"); then
	echo "SERVER_TAG ($SERVER_TAG) is invalid."
	exit 1
fi

# Correcting permissions on ftp home
STATUS=$(chown -R "$SERVER_TAG:php-fpm" "$HOME/sites-available/$SERVER_TAG" 2>&1)
STATUS=$(chmod -R 664 "$HOME/sites-available/$SERVER_TAG" 2>&1) # 664 so panel users can interact with ftp dirs
STATUS=$(chmod -R +X "$HOME/sites-available/$SERVER_TAG" 2>&1) # to give search bit to all directories

exit 0
