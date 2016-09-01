#!/bin/bash

# Allow only root execution
if (( $(id -u) != 0 )); then
	echo "This script requires root privileges"
	exit 1
fi

# Testing php-fpm
STATUS=$(/usr/sbin/php-fpm -t 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# Testing Nginx
STATUS=$(/usr/sbin/nginx -t 2>&1)	
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

exit 0
