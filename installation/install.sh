#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd -P)
ARCH=$(arch)
HOME=/var/www/WebPanel
MYSQL_ROOT_PSSWD="WebPanel"

HOME=${HOME%/}
if [[ $HOME == "" ]]; then
	echo "Home directory can't be '/' itself."
	exit 1
fi

# check if webpanel is already installed
if [[ -f /etc/default/webpanel ]]; then
	echo "WebPanel is already installed."
	exit 1
fi

# Allow only root execution
if (( $(id -u) != 0 )); then
	echo "This script requires root privileges"
	exit 1
fi

################## temporarily disable SELinux
setenforce 0

################## unistall mysql for conflicts
rpm -e --nodeps $(rpm -qa | grep '^mysql')
\mv /var/lib/mysql /var/lib/mysql.old
################## unistall memcached
rpm -e --nodeps $(rpm -qa | grep '^memcached')
################## unistall webalizer
rpm -e --nodeps $(rpm -qa | grep '^webalizer')
\mv /etc/webalizer.d/settings /etc/webalizer.d/settings.old
################## unistall php
rpm -e --nodeps $(rpm -qa | grep '^php')
\mv /etc/php-fpm.d/settings /etc/php-fpm.d/settings.old
################## unistall apache
rpm -e --nodeps $(rpm -qa | grep '^httpd')
\mv /etc/httpd/settings /etc/httpd/settings.old
\mv /var/www /var/www.old
################## unistall nginx
rpm -e --nodeps $(rpm -qa | grep '^nginx')
\mv /etc/nginx/settings /etc/nginx/settings.old
################## unistall vsftpd
rpm -e --nodeps $(rpm -qa | grep '^vsftpd')
\mv /etc/vsftpd/settings /etc/vsftpd/settings.old
################## unistall bind
rpm -e --nodeps $(rpm -qa | grep '^bind')
################## unistall exim
rpm -e --nodeps $(rpm -qa | grep '^exim')
################## unistall rpmforge-release
rpm -e --nodeps $(rpm -qa | grep '^rpmforge-release')
################## unistall epel-release
rpm -e --nodeps $(rpm -qa | grep '^epel-release')


################## repos
\cp "$SCRIPT_DIR/repos/CentOS-Base.repo" /etc/yum.repos.d/CentOS-Base.repo
\cp "$SCRIPT_DIR/repos/epel.repo" /etc/yum.repos.d/epel.repo
\cp "$SCRIPT_DIR/repos/ius.repo" /etc/yum.repos.d/ius.repo
\cp "$SCRIPT_DIR/repos/ius-archive.repo" /etc/yum.repos.d/ius-archive.repo
\cp "$SCRIPT_DIR/repos/MariaDB.repo" /etc/yum.repos.d/MariaDB.repo
\cp "$SCRIPT_DIR/repos/nginx.repo" /etc/yum.repos.d/nginx.repo
\cp "$SCRIPT_DIR/repos/rpmforge.repo" /etc/yum.repos.d/rpmforge.repo

################# yum plugins
yum clean all
STATUS=$(yum check-update 2>&1)
yum -y install yum-plugin-priorities yum-plugin-rpm-warm-cache yum-plugin-local deltarpm yum-plugin-fastestmirror

# installing packages
yum -y install htop nmap iftop iotop bind-utils mailx wget unzip
# TODO: install `php70u-pecl-memcached` when released
yum -y install bind MariaDB-server MariaDB-client nginx memcached redis32u php70u-cli php70u-fpm php70u-gd php70u-intl php70u-json php70u-mbstring php70u-mcrypt php70u-mysqlnd php70u-opcache php70u-pdo php70u-pear php70u-pecl-apcu php70u-pecl-redis php70u-soap php70u-xml

# update operating system
yum -y update

################## server configs
\cp /etc/selinux/config /etc/selinux/config.bak
\cp "$SCRIPT_DIR/settings/selinux/config" /etc/selinux/config

\cp /etc/sudoers /etc/sudoers.bak
\cp "$SCRIPT_DIR/settings/sudoers/sudoers" /etc/sudoers

\cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
\cp "$SCRIPT_DIR/settings/ssh/sshd_config" /etc/ssh/sshd_config

################# config after install
chmod 750 $(find "$SCRIPT_DIR/../cmd" -name "*" | grep \.sh$)

# Web
mkdir -p "$HOME/sites-available"
mkdir -p "$HOME/sites-enabled"
mkdir -p "$HOME/sites-available-for-humans"
mkdir -p "$HOME/sites-enabled-for-humans"

# Nginx
\mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.disabled
mkdir -p /etc/nginx/settings/sites-available
mkdir -p /etc/nginx/settings/sites-enabled
mkdir -p /etc/nginx/settings/sites-available-for-humans
mkdir -p /etc/nginx/settings/sites-enabled-for-humans

\cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
\cp "$SCRIPT_DIR/settings/nginx/nginx.conf" /etc/nginx/nginx.conf
\cp "$SCRIPT_DIR/settings/nginx/nginx_default_server.conf" /etc/nginx/nginx_default_server.conf

# PHP-FPM
mkdir -p /etc/php-fpm.d/settings/sites-available
mkdir -p /etc/php-fpm.d/settings/sites-enabled
mkdir -p /etc/php-fpm.d/settings/sites-available-for-humans
mkdir -p /etc/php-fpm.d/settings/sites-enabled-for-humans

\mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bak

\cp /etc/php-fpm.conf /etc/php-fpm.conf.bak
\cp "$SCRIPT_DIR/settings/php-fpm/php-fpm.conf" /etc/php-fpm.conf

\cp "$SCRIPT_DIR/settings/php-fpm/logrotate.d.php-fpm" /etc/logrotate.d/php-fpm
chmod 770 /var/log/php-fpm

# PHP
\cp /etc/php.ini /etc/php.ini.bak
\cp "$SCRIPT_DIR/settings/php/php.ini" /etc/php.ini

\cp "/etc/php.d/10-opcache.ini" "/etc/php.d/10-opcache.ini.bak"
\cp "$SCRIPT_DIR/settings/php/10-opcache.ini" "/etc/php.d/10-opcache.ini"

# Bind
\cp /etc/named.conf /etc/named.conf.bak
\cp "$SCRIPT_DIR/settings/bind/named.conf" "/etc/named.conf"
touch /etc/named/named.conf.local
mkdir -p /etc/named/zones

# Enabling servers
systemctl enable php-fpm
systemctl enable mariadb
systemctl enable memcached
systemctl enable redis
systemctl enable nginx
systemctl enable named

# Starting servers
systemctl start php-fpm
systemctl start mariadb
systemctl start memcached
systemctl start redis
systemctl start nginx
systemctl start named

#mysql_secure_installation
mysql -u root <<EOF
UPDATE mysql.user SET Password=PASSWORD('$MYSQL_ROOT_PSSWD') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
USE test;
DROP DATABASE test;
FLUSH PRIVILEGES;
EOF

touch /etc/default/webpanel
echo "WebPanel is installed"
