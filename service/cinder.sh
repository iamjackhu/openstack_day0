#!/bin/bash

function install_cinder_on_controller
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4
	MY_IP=$5
	STORAGE_TYPE=$6
	RBD_UUID=$7

	ssh root@$TARGET "mysql -e \"CREATE DATABASE cinder;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON cinder.* TO cinder@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON cinder.* TO cinder@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc;openstack user create --domain default --password $PASSWD cinder"
	ssh root@$TARGET ". adminrc;openstack role add --project service --user cinder admin"
	ssh root@$TARGET ". adminrc;openstack service create --name cinder --description \"OpenStack Block Storage\" volume"
	ssh root@$TARGET ". adminrc;openstack service create --name cinderv2 --description \"OpenStack Block Storage\" volumev2"

	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volume public http://$TARGET:8776/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volume internal http://$TARGET:8776/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volume admin http://$TARGET:8776/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volumev2 public http://$TARGET:8776/v2/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volumev2 internal http://$TARGET:8776/v2/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne volumev2 admin http://$TARGET:8776/v2/%\(tenant_id\)s"

	ssh root@$TARGET "yum install -y openstack-cinder"

	### /etc/cinder/cinder.conf
	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://cinder:$PASSWD@$TARGET/cinder" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$TARGET" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "my_ip = $MY_IP" ' /etc/cinder/cinder.conf"

	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$TARGET:5000\\n\
auth_url = http://$TARGET:35357\\n\
memcached_servers = $TARGET:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = cinder\\n\
password = $PASSWD" ' /etc/cinder/cinder.conf"

	ssh root@$TARGET "sed -i '/^\[oslo_concurrency\]/a "lock_path = /var/lib/cinder/tmp" ' /etc/cinder/cinder.conf"
	
	### with ceph
	if [ "$STORAGE_TYPE" = "ceph" ]; then
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "enabled_backends = ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "glance_host = $CONTROLLER" ' /etc/cinder/cinder.conf"
		
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_driver = cinder.backup.drivers.ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_conf = /etc/ceph/ceph.conf" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_user = cinder-backup" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_chunk_size = 134217728" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_pool = backups" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_stripe_unit = 0" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_stripe_count = 0" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "restore_discard_excess_bytes = true" ' /etc/cinder/cinder.conf"

		ssh root@$TARGET "echo '[ceph]' >> /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "volume_driver = cinder.volume.drivers.rbd.RBDDriver" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "volume_backend_name = ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_pool = volumes" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_ceph_conf = /etc/ceph/ceph.conf" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_flatten_volume_from_snapshot = false" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_max_clone_depth = 5" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_store_chunk_size = 4" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rados_connect_timeout = -1" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "glance_api_version = 2" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_user = cinder" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_secret_uuid = $RBD_UUID" ' /etc/cinder/cinder.conf"

		ssh root@$TARGET "ceph auth get-or-create client.cinder > /etc/ceph/ceph.client.cinder.keyring"
    	ssh root@$TARGET "sudo chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring"
    	ssh root@$TARGET "ceph auth get-or-create client.cinder-backup > /etc/ceph/ceph.client.cinder-backup.keyring"
    	ssh root@$TARGET "sudo chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring"
	fi


	ssh root@$TARGET "su -s /bin/sh -c \"cinder-manage db sync\" cinder"

	#### /etc/nova/nova.conf
	ssh root@$TARGET "sed -i '/^\[cinder\]/a "os_region_name = RegionOne" ' /etc/nova/nova.conf"

	ssh root@$TARGET "systemctl restart openstack-nova-api.service"
	ssh root@$TARGET "systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service"
	ssh root@$TARGET "systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service"

}


function install_cinder_on_storage
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4
	MY_IP=$5
	CONTROLLER=$6
	STORAGE_TYPE=$7
	RBD_UUID=$8

	ssh root@$TARGET "yum install -y openstack-cinder targetcli python-keystone"

	### /etc/cinder/cinder.conf
	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://cinder:$PASSWD@$CONTROLLER/cinder" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$CONTROLLER" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "auth_strategy = keystone" ' /etc/cinder/cinder.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "my_ip = $MY_IP" ' /etc/cinder/cinder.conf"
	
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "glance_api_servers = http://$CONTROLLER:9292" ' /etc/cinder/cinder.conf"

	### with ceph
	if [ "$STORAGE_TYPE" = "ceph" ]; then
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "enabled_backends = ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "glance_host = $CONTROLLER" ' /etc/cinder/cinder.conf"
		
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_driver = cinder.backup.drivers.ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_conf = /etc/ceph/ceph.conf" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_user = cinder-backup" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_chunk_size = 134217728" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_pool = backups" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_stripe_unit = 0" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "backup_ceph_stripe_count = 0" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "restore_discard_excess_bytes = true" ' /etc/cinder/cinder.conf"

		ssh root@$TARGET "echo '[ceph]' >> /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "volume_driver = cinder.volume.drivers.rbd.RBDDriver" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "volume_backend_name = ceph" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_pool = volumes" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_ceph_conf = /etc/ceph/ceph.conf" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_flatten_volume_from_snapshot = false" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_max_clone_depth = 5" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_store_chunk_size = 4" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rados_connect_timeout = -1" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "glance_api_version = 2" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_user = cinder" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[ceph\]/a "rbd_secret_uuid = $RBD_UUID" ' /etc/cinder/cinder.conf"

		ssh root@$TARGET "ceph auth get-or-create client.cinder > /etc/ceph/ceph.client.cinder.keyring"
		ssh root@$TARGET "sudo chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring"
		ssh root@$TARGET "ceph auth get-or-create client.cinder-backup > /etc/ceph/ceph.client.cinder-backup.keyring"
		ssh root@$TARGET "sudo chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring"
		ssh root@$TARGET "ceph auth get-or-create client.glance > /etc/ceph/ceph.client.glance.keyring"
		ssh root@$TARGET "sudo chown glance:glance /etc/ceph/ceph.client.glance.keyring"
	else
		ssh root@$TARGET "yum install -y lvm2"
		ssh root@$TARGET "systemctl enable lvm2-lvmetad.service"
		ssh root@$TARGET "systemctl restart lvm2-lvmetad.service"

		ssh root@$TARGET "pvcreate /dev/sda3"
		ssh root@$TARGET "vgcreate cinder-volumes /dev/sda3"
		ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "enabled_backends = lvm" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[lvm\]/a "volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[lvm\]/a "volume_group = cinder-volumes" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[lvm\]/a "iscsi_protocol = iscsi" ' /etc/cinder/cinder.conf"
		ssh root@$TARGET "sed -i '/^\[lvm\]/a "iscsi_helper = lioadm" ' /etc/cinder/cinder.conf"
	fi

	ssh root@$TARGET "sed -i '/^\[keystone_authtoken\]/a "auth_uri = http://$CONTROLLER:5000\\n\
auth_url = http://$CONTROLLER:35357\\n\
memcached_servers = $CONTROLLER:11211\\n\
auth_type = password\\n\
project_domain_name = Default\\n\
user_domain_name = Default\\n\
project_name = service\\n\
username = cinder\\n\
password = $PASSWD" ' /etc/cinder/cinder.conf"


	ssh root@$TARGET "sed -i '/^\[oslo_concurrency\]/a "lock_path = /var/lib/cinder/tmp" ' /etc/cinder/cinder.conf"
	
	#### /etc/nova/nova.conf
	ssh root@$TARGET "sed -i '/^\[cinder\]/a "os_region_name = RegionOne" ' /etc/nova/nova.conf"
	ssh root@$TARGET "systemctl restart openstack-nova-compute.service"

	ssh root@$TARGET "systemctl enable openstack-cinder-volume.service target.service"
	ssh root@$TARGET "systemctl restart openstack-cinder-volume.service target.service"

}