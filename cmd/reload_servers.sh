#!/bin/bash

# Allow only root execution
if (( $(id -u) != 0 )); then
	echo "This script requires root privileges"
	exit 1
fi

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)

# In case some servers aren't already up
STATUS=$(/usr/bin/systemctl start php-fpm 2>&1)
STATUS=$(ps aux | grep php[-]fpm 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

STATUS=$(/usr/bin/systemctl start nginx 2>&1)
STATUS=$(ps aux | grep ngin[x] 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

STATUS=$(/usr/bin/systemctl start named 2>&1)
STATUS=$(ps aux | grep nam[e]d 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

STATUS=$(/usr/bin/systemctl start redis 2>&1)
STATUS=$(/usr/bin/systemctl start memcached 2>&1)

# Testing server configs
STATUS=$(sh "$SCRIPT_DIR/test_servers.sh" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# Reloading php-fpm
STATUS=$(/usr/bin/systemctl reload php-fpm 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# Reloading nginx
STATUS=$(/usr/bin/systemctl reload nginx 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# Reloading named
STATUS=$(/usr/bin/systemctl reload named 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

exit 0
