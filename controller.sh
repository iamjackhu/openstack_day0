#!/bin/bash

function install_mysql
{
	TARGET=$1
	PASSWD=$2
	ssh root@$TARGET "yum -y install mariadb mariadb-server python2-PyMySQL"

	#create /etc/my.cnf.d/openstack.cnf
	ssh root@$TARGET "echo -e '[mysqld]\nbind-address = $TARGET \n\
default-storage-engine = innodb \n\
innodb_file_per_table \n\
max_connections = 4096 \n\
collation-server = utf8_general_ci \n\
character-set-server = utf8 '\
		> /tmp/openstack.cnf"

	ssh root@$TARGET "systemctl enable mariadb.service"
	ssh root@$TARGET "systemctl start mariadb.service"

	#mysql_secure_installation
	ssh root@$TARGET "mysql_secure_installation <<EOF

Y
$PASSWD
$PASSWD
Y
Y
Y
Y
EOF"
	
}

function install_rabitmq
{
	TARGET=$1
	PASSWD=$2
	ssh root@$TARGET "yum -y rabbitmq-server"
	ssh root@$TARGET "systemctl enable rabbitmq-server.service"
	ssh root@$TARGET "systemctl start rabbitmq-server.service"
	ssh root@$TARGET "rabbitmqctl add_user openstack $PASSWD"
	ssh root@$TARGET "rabbitmqctl set_permissions openstack \".*\" \".*\" \".*\" "
}

function install_memcached
{
	TARGET=$1
	ssh root@$TARGET "yum -y memcached python-memcached"
	ssh root@$TARGET "systemctl enable memcached.service"
	ssh root@$TARGET "systemctl start memcached.service"
}

function install_identity
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3

	ssh root@$TARGET "mysql -u root -p<<EOF
$MYSQLPASSWD
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
  IDENTIFIED BY '$PASSWD';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
  IDENTIFIED BY '$PASSWD';
exit;
EOF
"

	ssh root@$TARGET "yum -y install openstack-keystone httpd mod_wsgi"
}

