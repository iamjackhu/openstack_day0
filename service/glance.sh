#!/bin/bash

function install_glance
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3

	ssh root@$TARGET "mysql -e \"CREATE DATABASE glance;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON glance.* TO glance@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON glance.* TO glance@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc;openstack user create --domain default --password $PASSWD glance"

	ssh root@$TARGET ". adminrc;openstack role add --project service --user glance admin"
	ssh root@$TARGET ". adminrc;openstack service create --name glance --description \"OpenStack Image\" image"

	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne image public http://$TARGET:9292"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne image internal http://$TARGET:9292"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne image admin http://$TARGET:9292"

	ssh root@$TARGET "yum -y install openstack-glance"

	#/etc/glance/glance-api.conf
	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://glance:$PASSWD@$TARGET/glance" ' /etc/glance/glance-api.conf"
	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\\n\
auth_url = http://$TARGET:35357\\n\
memcached_servers = $TARGET:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = glance\\n\
password = $PASSWD\\n\
" ' /etc/glance/glance-api.conf"
	ssh root@$TARGET "sed -i '/\[paste_deploy\]/a "flavor = keystone\\n" ' /etc/glance/glance-api.conf"
	ssh root@$TARGET "sed -i '/\[glance_store\]/a "stores = file,http\\ndefault_store = file\\nfilesystem_store_datadir = /home/glance/images" ' /etc/glance/glance-api.conf"
	ssh root@$TARGET "chmod 777 /home"
	ssh root@$TARGET "su -s /bin/sh -c \"mkdir -p /home/glance/images/\" glance"

	#/etc/glance/glance-registry.conf
	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://glance:$PASSWD@$TARGET/glance" ' /etc/glance/glance-registry.conf"
	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\\n\
auth_url = http://$TARGET:35357\\n\
memcached_servers = $TARGET:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = glance\\n\
password = $PASSWD\\n\
" ' /etc/glance/glance-registry.conf"
	ssh root@$TARGET "sed -i '/\[paste_deploy\]/a "flavor = keystone\\n" ' /etc/glance/glance-registry.conf"

	ssh root@$TARGET "su -s /bin/sh -c \"glance-manage db_sync\" glance"

	ssh root@$TARGET "systemctl enable openstack-glance-api.service \
  openstack-glance-registry.service"
	ssh root@$TARGET "systemctl start openstack-glance-api.service \
  openstack-glance-registry.service"


  echo "### Glance installed"
}