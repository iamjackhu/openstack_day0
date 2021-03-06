#!/bin/bash

function install_compute_on_controller
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4
	MY_IP=$5

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
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova_api.* TO nova@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON nova_api.* TO nova@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc"

	ssh root@$TARGET ". adminrc;openstack user create --domain default --password $PASSWD nova"

	ssh root@$TARGET ". adminrc;openstack role add --project service --user nova admin"
	ssh root@$TARGET ". adminrc;openstack service create --name nova --description \"OpenStack Compute\" compute"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne compute public http://$TARGET:8774/v2.1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne compute internal http://$TARGET:8774/v2.1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne compute admin http://$TARGET:8774/v2.1/%\(tenant_id\)s"

	ssh root@$TARGET "yum -y --nogpgcheck install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler"

  	#/etc/nova/nova.conf
  	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://nova:$PASSWD@$TARGET/nova" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[api_database\]/a "connection = mysql+pymysql://nova:$PASSWD@$TARGET/nova_api" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "enabled_apis = osapi_compute,metadata" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$TARGET" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "my_ip = $MY_IP" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "use_neutron = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "firewall_driver = nova.virt.firewall.NoopFirewallDriver" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\\n\
auth_url = http://$TARGET:35357\\n\
memcached_servers = $TARGET:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = nova\\n\
password = $PASSWD" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/^\[vnc\]/a "vncserver_listen = $MY_IP" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[vnc\]/a "vncserver_proxyclient_address = $MY_IP" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[glance\]/a "api_servers = http://$TARGET:9292" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[oslo_concurrency\]/a "lock_path = /var/lib/nova/tmp" ' /etc/nova/nova.conf"
	
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
	MY_IP=$5
	STORAGE_TYPE=$6
	RBD_UUID=$7

	ssh root@$TARGET "yum -y --nogpgcheck install openstack-nova-compute"

	#/etc/nova/nova.conf

	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "enabled_apis = osapi_compute,metadata" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$CONTROLLER" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "my_ip = ${MY_IP}" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "use_neutron = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "firewall_driver = nova.virt.firewall.NoopFirewallDriver" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$CONTROLLER:5000\\n\
auth_url = http://$CONTROLLER:35357\\n\
memcached_servers = $CONTROLLER:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = nova\\n\
password = $PASSWD" ' /etc/nova/nova.conf"
	
	ssh root@$TARGET "sed -i '/^\[vnc\]/a "enabled = True" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[vnc\]/a "vncserver_listen = 0.0.0.0" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[vnc\]/a "vncserver_proxyclient_address = $MY_IP" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[vnc\]/a "novncproxy_base_url = http://$CONTROLLER:6080/vnc_auto.html" ' /etc/nova/nova.conf"

	ssh root@$TARGET "sed -i '/^\[glance\]/a "api_servers = http://$CONTROLLER:9292" ' /etc/nova/nova.conf"
	ssh root@$TARGET "sed -i '/^\[oslo_concurrency\]/a "lock_path = /var/lib/nova/tmp" ' /etc/nova/nova.conf"
	
	if [ "$STORAGE_TYPE" = "ceph" ]; then
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "rbd_user = cinder" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "rbd_secret_uuid = $RBD_UUID" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "inject_password = false" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "inject_key = false" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "inject_partition = -2" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "disk_cachemodes=\"network=writeback\"" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "libvirt_images_type = rbd" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "libvirt_images_rbd_pool = vms" ' /etc/nova/nova.conf"
		ssh root@$TARGET "sed -i '/^\[libvirt\]/a "libvirt_images_rbd_ceph_conf = /etc/ceph/ceph.conf" ' /etc/nova/nova.conf"
	fi

	ssh root@$TARGET "systemctl enable libvirtd.service openstack-nova-compute.service"
	ssh root@$TARGET "systemctl restart libvirtd.service openstack-nova-compute.service"

	if [ "$STORAGE_TYPE" = "ceph" ]; then
		ssh root@$TARGET "echo '<secret ephemeral='no' private='no'>
  <uuid>8033ef86-0be1-11e7-93ae-92361f002671</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>' > secret.xml" 
		ssh root@$TARGET "virsh secret-define --file secret.xml"
		ssh root@$TARGET "virsh secret-set-value --secret 8033ef86-0be1-11e7-93ae-92361f002671 --base64 AQANrc5YInkrARAA2cqo0yd/gbeCHQ4EAGezRQ=="
		ssh root@$TARGET "mkdir /var/run/ceph/guests/ /var/log/qemu/"
		ssh root@$TARGET "chmod 777 /var/run/ceph/guests/ /var/log/qemu/"
		ssh root@$TARGET "systemctl restart libvirtd.service openstack-nova-compute.service"
	fi
}