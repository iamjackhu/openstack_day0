#!/bin/bash

function install_network_on_controller
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4
	NOVA_PASS=$5
	INTERFACE=$6

	ssh root@$TARGET "mysql -e \"CREATE DATABASE neutron;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON neutron.* TO neutron@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON neutron.* TO neutron@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc"

	ssh root@$TARGET "openstack user create --domain default --password $PASSWD neutron"
	
	ssh root@$TARGET "openstack role add --project service --user neutron admin"
	ssh root@$TARGET "openstack service create --name neutron --description \"OpenStack Networking\" network"

	ssh root@$TARGET "openstack endpoint create --region RegionOne network public http://$TARGET:9696"
	ssh root@$TARGET "openstack endpoint create --region RegionOne network internal http://$TARGET:9696"
	ssh root@$TARGET "openstack endpoint create --region RegionOne network admin http://$TARGET:9696"

	# provider network
	ssh root@$TARGET "yum -y install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables"

  	#/etc/neutron/neutron.conf
  	ssh root@$TARGET "sed -i '/\[database\]/a "connection = mysql+pymysql://neutron:$PASSWD@$TARGET/neutron" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "core_plugin = ml2" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "service_plugins =" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$TARGET" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "notify_nova_on_port_status_changes = True" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "notify_nova_on_port_data_changes = True" ' /etc/neutron/neutron.conf"
	
	ssh root@$TARGET "sed -i '/\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\n\
auth_url = http://$TARGET:35357\n\
memcached_servers = $TARGET:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = neutron\n\
password = $PASSWD" ' /etc/neutron/neutron.conf"

	ssh root@$TARGET "sed -i '/\[nova\]/a "auth_url = http://$TARGET:35357\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
region_name = RegionOne\n\
project_name = service\n\
username = nova\n\
password = $NOVA_PASS" ' /etc/neutron/neutron.conf"
	
	ssh root@$TARGET "sed -i '/\[oslo_concurrency\]/a "lock_path = /var/lib/neutron/tmp" ' /etc/neutron/neutron.conf"
	
	#/etc/neutron/plugins/ml2/ml2_conf.ini	
	ssh root@$TARGET "sed -i '/\[ml2\]/a "type_drivers = flat,vlan" ' /etc/neutron/plugins/ml2/ml2_conf.ini"
	ssh root@$TARGET "sed -i '/\[ml2\]/a "tenant_network_types =" ' /etc/neutron/plugins/ml2/ml2_conf.ini"
	ssh root@$TARGET "sed -i '/\[ml2\]/a "mechanism_drivers = linuxbridge" ' /etc/neutron/plugins/ml2/ml2_conf.ini"
	ssh root@$TARGET "sed -i '/\[ml2\]/a "extension_drivers = port_security" ' /etc/neutron/plugins/ml2/ml2_conf.ini"
	ssh root@$TARGET "sed -i '/\[ml2\]/a "flat_networks = provider" ' /etc/neutron/plugins/ml2/ml2_conf.ini	"
	ssh root@$TARGET "sed -i '/\[ml2\]/a "enable_ipset = True" ' /etc/neutron/plugins/ml2/ml2_conf.ini	"
	
	#/etc/neutron/plugins/ml2/linuxbridge_agent.ini
	ssh root@$TARGET "sed -i '/\[linux_bridge\]/a "physical_interface_mappings = provider:$INTERFACE" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[vxlan\]/a "enable_vxlan = False" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[securitygroup\]/a "enable_security_group = True" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[securitygroup\]/a "firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	
	#/etc/neutron/dhcp_agent.ini
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver" ' /etc/neutron/dhcp_agent.ini"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq" ' /etc/neutron/dhcp_agent.ini"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "enable_isolated_metadata = True" ' /etc/neutron/dhcp_agent.ini"
	
	#/etc/neutron/metadata_agent.ini 
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "nova_metadata_ip = $TARGET" ' /etc/neutron/dhcp_agent.ini"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "metadata_proxy_shared_secret = METADATA_SECRET" ' /etc/neutron/dhcp_agent.ini"
	
	#/etc/nova/nova.conf
	ssh root@$TARGET "sed -i '/\[neutron\]/a "auth_url = http://$TARGET:9696\n\
auth_url = http://$TARGET:35357\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
region_name = RegionOne\n\
project_name = service\n\
username = neutron\n\
password = $PASSWD\n\
service_metadata_proxy = True\n\
metadata_proxy_shared_secret = METADATA_SECRET" ' /etc/nova/nova.conf"

	ssh root@$TARGET "ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"
	ssh root@$TARGET "su -s /bin/sh -c \"neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head\" neutron"

  	ssh root@$TARGET "systemctl restart openstack-nova-api.service"
  	ssh root@$TARGET "systemctl enable neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service"
  	ssh root@$TARGET "systemctl start neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service"
}

function install_network_on_computer
{
	TARGET=$1
	PASSWD=$2
	CONTROLLER=$3
	RABBIT_PASSWD=$4
	NOVA_PASS=$5
	INTERFACE=$6

	ssh root@$TARGET "yum -y openstack-neutron-linuxbridge ebtables ipset"

	#/etc/neutron/neutron.conf
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$CONTROLLER" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/neutron/neutron.conf"

	ssh root@$TARGET "sed -i '/\[keystone_authtoken\]/a "auth_uri = http://$CONTROLLER:5000\n\
auth_url = http://$CONTROLLER:35357\n\
memcached_servers = $CONTROLLER:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = neutron\n\
password = $PASSWD" ' /etc/neutron/neutron.conf"
	ssh root@$TARGET "sed -i '/\[oslo_concurrency\]/a "lock_path = /var/lib/neutron/tmp" ' /etc/neutron/neutron.conf"
	
	# provider network for computer
	#/etc/neutron/plugins/ml2/linuxbridge_agent.ini
	ssh root@$TARGET "sed -i '/\[linux_bridge\]/a "physical_interface_mappings = provider:$INTERFACE" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[vxlan\]/a "enable_vxlan = False" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[securitygroup\]/a "enable_security_group = True" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	ssh root@$TARGET "sed -i '/\[securitygroup\]/a "firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver" ' /etc/neutron/plugins/ml2/linuxbridge_agent.ini"
	
	#/etc/nova/nova.conf
	ssh root@$TARGET "sed -i '/\[keystone_authtoken\]/a "url = http://$CONTROLLER:9696\n\
auth_url = http://$CONTROLLER:35357\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
region_name = RegionOne\n\
project_name = service\n\
username = neutron\n\
password = $PASSWD" ' /etc/nova/nova.conf"

	ssh root@$TARGET "systemctl restart openstack-nova-compute.service"
	ssh root@$TARGET "systemctl enable neutron-linuxbridge-agent.service"
	ssh root@$TARGET "systemctl start neutron-linuxbridge-agent.service"
}