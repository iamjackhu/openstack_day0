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
		> /etc/my.cnf.d/openstack.cnf"

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
	
	echo "### MySQL installed"
}