#!/bin/bash

# $1:server_tag, $2:server_name, $3:server_port

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
WEB_ROOT_DIR="web"
SHELL="/sbin/nologin"
HOME="/var/www/WebPanel"
MYSQL_ROOT_PSSWD="WebPanel"

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
SERVER_IP=$(echo $(hostname -I | cut -d" " -f 1))

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

# Check if ftp home already exists
if [[ ! -e "$HOME/sites-available/$SERVER_TAG" ]]; then

    # Creating session,soap and opcache directories
    STATUS=$(mkdir -p "/var/lib/php/fpm/session/$SERVER_TAG" 2>&1)
    STATUS=$(chown "root:php-fpm" "/var/lib/php/fpm/session/$SERVER_TAG" 2>&1)
    STATUS=$(chmod 770 "/var/lib/php/fpm/session/$SERVER_TAG" 2>&1)
    
    STATUS=$(mkdir -p "/var/lib/php/fpm/wsdlcache/$SERVER_TAG" 2>&1)
    STATUS=$(chown "root:php-fpm" "/var/lib/php/fpm/wsdlcache/$SERVER_TAG" 2>&1)
    STATUS=$(chmod 770 "/var/lib/php/fpm/wsdlcache/$SERVER_TAG" 2>&1)
    
    STATUS=$(mkdir -p "/var/lib/php/fpm/opcache/$SERVER_TAG" 2>&1)
    STATUS=$(chown "root:php-fpm" "/var/lib/php/fpm/opcache/$SERVER_TAG" 2>&1)
    STATUS=$(chmod 770 "/var/lib/php/fpm/opcache/$SERVER_TAG" 2>&1)
    
    # creating ftp home & web root
    STATUS=$(mkdir -p "$HOME/sites-available/$SERVER_TAG/$WEB_ROOT_DIR" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi

    STATUS=$(ln -fs "../sites-available/$SERVER_TAG/" "$HOME/sites-enabled/$SERVER_TAG" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG/" "$HOME/sites-available-for-humans/$SERVER_PORT.$SERVER_NAME" 2>&1)
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG/" "$HOME/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME" 2>&1)

    # Creating user
    STATUS=$(id "$SERVER_TAG" 2>&1)
    if (( $? == 0 )); then
        # user exists
        STATUS=$(usermod --comment "$SERVER_NAME $SERVER_PORT" -g php-fpm --home "$HOME/sites-available/$SERVER_TAG" --shell "$SHELL" "$SERVER_TAG" 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi
    else
        # user doesn't exist
        STATUS=$(useradd --comment "$SERVER_NAME $SERVER_PORT" -g php-fpm --home "$HOME/sites-available/$SERVER_TAG" --shell "$SHELL" "$SERVER_TAG" 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi
    fi
    
    # Copying default index page
    STATUS=$(\cp "$SCRIPT_DIR/templates/web/index.php" "$HOME/sites-available/$SERVER_TAG/$WEB_ROOT_DIR/index.php" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    else
        STATUS=$(sed -i -e"s/web001/$SERVER_TAG/g" "$HOME/sites-available/$SERVER_TAG/$WEB_ROOT_DIR/index.php" 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi
    fi
    
    # Correcting permissions on ftp home
    STATUS=$(chown -R "$SERVER_TAG:php-fpm" "$HOME/sites-available/$SERVER_TAG" 2>&1)
    STATUS=$(chmod -R 664 "$HOME/sites-available/$SERVER_TAG" 2>&1) # 664 so panel users can interact with ftp dirs
    STATUS=$(chmod -R +X "$HOME/sites-available/$SERVER_TAG" 2>&1) # to give search bit to all directories
    
    ##################### Creating PHP-FPM pool definition
    STATUS=$(\mv "/etc/php-fpm.d/settings/sites-available/$SERVER_TAG.conf" "/etc/php-fpm.d/settings/sites-available/$SERVER_TAG.conf.bak" 2>&1)
    
    STATUS=$(\cp "$SCRIPT_DIR/templates/php-fpm/web001.conf" "/etc/php-fpm.d/settings/sites-available/$SERVER_TAG.conf" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    else
        STATUS=$(sed -i -e"s/web001/$SERVER_TAG/g" "/etc/php-fpm.d/settings/sites-available/$SERVER_TAG.conf" 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi
    fi
    
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/php-fpm.d/settings/sites-enabled/$SERVER_TAG.conf" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/php-fpm.d/settings/sites-available-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/php-fpm.d/settings/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)

    ##################### Creating nginx virtual host
    STATUS=$(\mv "/etc/nginx/settings/sites-available/$SERVER_TAG.conf" "/etc/nginx/settings/sites-available/$SERVER_TAG.conf.bak" 2>&1)
    
    STATUS=$(\cp "$SCRIPT_DIR/templates/nginx/web001.conf" "/etc/nginx/settings/sites-available/$SERVER_TAG.conf" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    else
        STATUS=$(sed -i -e"s/web001/$SERVER_TAG/g" -e"s/server_name .*/server_name $SERVER_NAME;/" -e"s/listen .*/listen $SERVER_PORT;/" "/etc/nginx/settings/sites-available/$SERVER_TAG.conf" 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi  
    fi
    
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/nginx/settings/sites-enabled/$SERVER_TAG.conf" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/nginx/settings/sites-available-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)
    STATUS=$(ln -fs "../sites-available/$SERVER_TAG.conf" "/etc/nginx/settings/sites-enabled-for-humans/$SERVER_PORT.$SERVER_NAME.conf" 2>&1)
    
    ##################### Adding server_name to DNS server
    STATUS=$(touch /etc/named/named.conf.local 2>&1)
    
    STATUS=$(grep -Fq "\"$SERVER_NAME\"" /etc/named/named.conf.local 2>&1)
    if (( $? != 0 )); then
        ZONE_SETTINGS=$(< "$SCRIPT_DIR/templates/bind/named.conf.local")
        ZONE_SETTINGS=$(echo "$ZONE_SETTINGS" | sed -e "s/example\.com/$SERVER_NAME/g")
        STATUS=$(echo "$ZONE_SETTINGS" >> /etc/named/named.conf.local 2>&1)
        if (( $? != 0 )); then
            echo "$STATUS"
            STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
            exit 1
        fi
    fi
    
    STATUS=$(\cp "$SCRIPT_DIR/templates/bind/example.com.zone" "/etc/named/zones/$SERVER_NAME.zone" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    STATUS=$(sed -i -e"s/example\.com/$SERVER_NAME/g" -e"s/127\.0\.0\.1/$SERVER_IP/g" "/etc/named/zones/$SERVER_NAME.zone" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    ##################### Creating MySQL Database and User
	STATUS=$(mysql -u root -p${MYSQL_ROOT_PSSWD} -e "CREATE DATABASE ${SERVER_TAG} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1)
	if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
	
	STATUS=$(mysql -u root -p${MYSQL_ROOT_PSSWD} -e "CREATE USER ${SERVER_TAG}@127.0.0.1 IDENTIFIED BY '${SERVER_PORT}.${SERVER_NAME}';" 2>&1)
	if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
	
	STATUS=$(mysql -u root -p${MYSQL_ROOT_PSSWD} -e "GRANT ALL PRIVILEGES ON ${SERVER_TAG}.* TO '${SERVER_TAG}'@'127.0.0.1';" 2>&1)
	if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
	
	STATUS=$(mysql -u root -p${MYSQL_ROOT_PSSWD} -e "FLUSH PRIVILEGES;" 2>&1)    
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
    ##################### Reloading servers
    STATUS=$(sh "$SCRIPT_DIR/reload_servers.sh" 2>&1)
    if (( $? != 0 )); then
        echo "$STATUS"
        STATUS=$(sh "$SCRIPT_DIR/domaindis.sh $SERVER_TAG $SERVER_NAME $SERVER_PORT" 2>&1)
        exit 1
    fi
    
else
    echo "Directory ($HOME/sites-available/$SERVER_TAG) already exists."
    exit 1
fi

echo "Domain is created."
exit 0
