#!/bin/bash

function install_compute_on_controller
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4

	ssh root@$TARGET "mysql -e \"CREATE DATABASE nova_api;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"CREATE DATABASE nova;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova.* TO nova@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova.* TO nova@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova_api.* TO nova_api@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova_api.* TO nova_api@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc"

	ssh root@$TARGET "openstack user create --domain default --password-prompt nova<<EOF
$PASSWD
$PASSWD
EOF"

	ssh root@$TARGET "openstack role add --project service --user nova admin"
	ssh root@$TARGET "openstack service create --name nova --description \"OpenStack Compute\" compute"
	ssh root@$TARGET "openstack endpoint create --region RegionOne compute public http://$TARGET8774/v2.1/%\(tenant_id\)s"
	ssh root@$TARGET "openstack endpoint create --region RegionOne compute internal http://$TARGET:8774/v2.1/%\(tenant_id\)s"
	ssh root@$TARGET "openstack endpoint create --region RegionOne compute admin http://$TARGET:8774/v2.1/%\(tenant_id\)s"

	ssh root@$TARGET "yum -y install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler"

  	#/etc/nova/nova.conf
  	ssh root@$TARGET "sed -i '/\[database\]/a "connection = mysql+pymysql://nova:$PASSWD@$TARGET/nova" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[api_database\]/a "connection = mysql+pymysql://nova:$PASSWD@$TARGET/nova_api" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "enabled_apis = osapi_compute,metadata" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$TARGET" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "my_ip = $TARGET" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "use_neutron = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "firewall_driver = nova.virt.firewall.NoopFirewallDriver" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\n\
auth_url = http://$TARGET:35357\n\
memcached_servers = $TARGET:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = nova\n\
password = $PASSWD" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/\[vnc\]/a "vncserver_listen = $my_ip" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[vnc\]/a "vncserver_proxyclient_address = $my_ip" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[glance\]/a "api_servers = http://$TARGET:9292" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[oslo_concurrency\]/a "lock_path = /var/lib/nova/tmp" ' /etc/nova/nova.conf"
	
	ssh root@$TARGET "su -s /bin/sh -c \"nova-manage api_db sync\" nova"
	ssh root@$TARGET "su -s /bin/sh -c \"nova-manage db sync\" nova"

	ssh root@$TARGET "systemctl enable openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service"

  	ssh root@$TARGET "systemctl start openstack-nova-api.service \
  openstack-nova-consoleauth.service openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service"
}

function install_compute_on_computer
{
	TARGET=$1
	PASSWD=$2
	RABBIT_PASSWD=$3
	CONTROLLER=$4

	ssh root@$TARGET "yum -y instal openstack-nova-compute"

	#/etc/nova/nova.conf

	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "enabled_apis = osapi_compute,metadata" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$CONTROLLER" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "my_ip = $TARGET" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "use_neutron = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "firewall_driver = nova.virt.firewall.NoopFirewallDriver" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/\[keystone_authtoken\]/a "auth_uri = http://$CONTROLLER:5000\n\
auth_url = http://$CONTROLLER:35357\n\
memcached_servers = $CONTROLLER:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = nova\n\
password = $PASSWD" ' /etc/nova/nova.conf"
	
	ssh root@$TARGET "sed -i '/\[vnc\]/a "enabled = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[vnc\]/a "vncserver_listen = 0.0.0.0" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[vnc\]/a "vncserver_proxyclient_address = $my_ip" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[vnc\]/a "novncproxy_base_url = http://$CONTROLLER:6080/vnc_auto.html" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/\[glance\]/a "api_servers = http://$CONTROLLER:9292" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/\[oslo_concurrency\]/a "lock_path = /var/lib/nova/tmp" ' /etc/nova/nova.conf"
	
	ssh root@$TARGET "systemctl enable libvirtd.service openstack-nova-compute.service"
	ssh root@$TARGET "systemctl start libvirtd.service openstack-nova-compute.service"
}