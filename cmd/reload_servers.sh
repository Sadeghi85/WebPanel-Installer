#!/bin/bash

# Allow only root execution
if (( $(id -u) != 0 )); then
	echo "This script requires root privileges"
	exit 1
fi

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)

# in case some servers aren't already up
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

STATUS=$(/usr/bin/systemctl start memcached 2>&1)

# testing server configs
STATUS=$(sh "$SCRIPT_DIR/test_servers.sh" 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# reloading php-fpm
STATUS=$(/usr/bin/systemctl reload php-fpm 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

# reloading nginx
STATUS=$(/usr/bin/systemctl reload nginx 2>&1)
if (( $? != 0 )); then
	echo "$STATUS"
	exit 1
fi

exit 0
