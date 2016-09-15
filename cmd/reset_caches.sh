#!/bin/bash

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

STATUS=$(rm -rf /var/lib/php/fpm/session/web*/* 2>&1)
STATUS=$(rm -rf /var/lib/php/fpm/wsdlcache/web*/* 2>&1)
STATUS=$(rm -rf /var/lib/php/fpm/opcache/web*/* 2>&1)

exit 0
