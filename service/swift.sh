#!/bin/bash

function init_swift_hostname
{
	TARGET=$1
	ssh root@$TARGET "echo '10.0.3.102	proxy-server' >> /etc/hosts"
	ssh root@$TARGET "echo '10.0.3.103	swift1' >> /etc/hosts"
	ssh root@$TARGET "echo '10.0.3.104	swift2' >> /etc/hosts"
	ssh root@$TARGET "echo '10.0.3.105	swift3' >> /etc/hosts"
}

### this step need todo on the node which want to access the storage service
function install_common_on_each_node
{
	TARGET=$1

	# init_swift_hostname $TARGET

	ssh root@$TARGET "mkdir -p /etc/swift;"

	ssh root@$TARGET "yum -y --nogpgcheck install openstack-swift-proxy python-swiftclient memcached"

	ssh root@$TARGET "curl -o /etc/swift/swift.conf http://installer/install/openstack-config/swift.conf"
	ssh root@$TARGET "chown -R root:swift /etc/swift"
	#/etc/swift/swift.conf
	
	ssh root@$TARGET "systemctl enable openstack-swift-proxy.service memcached.service"
	ssh root@$TARGET "systemctl restart openstack-swift-proxy.service memcached.service"
}


function install_swift_on_controller
{
	TARGET=$1
	PASSWD=$2
	CONTROLLER=$3
	PROXYSERVER=$4

	init_swift_hostname $TARGET

	ssh root@$TARGET ". adminrc;openstack user create --domain default --password $PASSWD swift"
	ssh root@$TARGET ". adminrc;openstack role add --project service --user swift admin"
	ssh root@$TARGET ". adminrc;openstack service create --name swift --description \"OpenStack Object Storage\" object-store"

	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne object-store public http://$PROXYSERVER:8080/v1/AUTH_%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne object-store internal http://$PROXYSERVER:8080/v1/AUTH_%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne object-store admin http://$PROXYSERVER:8080/v1"

	ssh root@$TARGET "yum -y --nogpgcheck install openstack-swift-proxy python-swiftclient python-keystoneclient python-keystonemiddleware memcached "

	ssh root@$TARGET "curl -o /etc/swift/proxy-server.conf http://installer/install/openstack-config/proxy-server.conf"

	#/etc/swift/proxy-server.conf
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "user = swift" ' /etc/swift/proxy-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "swift_dir = /etc/swift" ' /etc/swift/proxy-server.conf"
	# ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_ip = $PROXYSERVER" ' /etc/swift/proxy-server.conf"

	ssh root@$TARGET "sed -i -e 's/ tempurl / authtoken /g' /etc/swift/proxy-server.conf"
	ssh root@$TARGET "sed -i -e 's/ tempauth / keystoneauth /g' /etc/swift/proxy-server.conf"
	
	ssh root@$TARGET "sed -i '/^\[app:proxy-server\]/a "account_autocreate = True" ' /etc/swift/proxy-server.conf"
	
	ssh root@$TARGET "echo '[filter:keystoneauth]' >> /etc/swift/proxy-server.conf"
	ssh root@$TARGET "echo 'use = egg:swift#keystoneauth' >> /etc/swift/proxy-server.conf"
	ssh root@$TARGET "echo 'operator_roles = admin,user' >> /etc/swift/proxy-server.conf"


	ssh root@$TARGET "sed -i '/^\[filter:authtoken\]/a "paste.filter_factory = keystonemiddleware.auth_token:filter_factory\\n\
auth_uri = http://$CONTROLLER:5000\\n\
auth_url = http://$CONTROLLER:35357\\n\
memcached_servers = $CONTROLLER:11211\\n\
auth_type = password\\n\
project_domain_name = default\\n\
user_domain_name = default\\n\
project_name = service\\n\
username = swift\\n\
password = $PASSWD\\n\
delay_auth_decision = True\\n\
	" ' /etc/swift/proxy-server.conf"
	
	ssh root@$TARGET "sed -i '/^\[filter:cache\]/a "memcache_servers = $CONTROLLER:11211" ' /etc/swift/proxy-server.conf"
	
	install_common_on_each_node $TARGET
}

function install_swift_on_storage
{
	TARGET=$1
	PASSWD=$2
	SWIFTIP=$3

	ssh root@$TARGET "yum -y --nogpgcheck install xfsprogs rsync "

# 	#### todo 
# 	#  parted /dev/sdb mklabel gpt
# 	ssh root@$TARGET "parted /dev/sdb mklabel gpt<<EOF
# Ignore
# Yes
# Ignore
# EOF"
# 	#  parted /dev/sdb mkpart primary xfs
# 	ssh root@$TARGET "parted /dev/sdb mkpart primary xfs<<EOF
# 1
# -1
# Ignore
# EOF"
# 	#
	ssh root@$TARGET "mkfs.xfs -f /dev/sdb"
	ssh root@$TARGET "mkdir -p /srv/node/sdb"

	#/etc/fstab
	ssh root@$TARGET "echo '/dev/sdb /srv/node/sdb xfs noatime,nodiratime,nobarrier,logbufs=8 0 2' >> /etc/fstab"

	ssh root@$TARGET "mount /srv/node/sdb"

	# /etc/rsyncd.conf
	ssh root@$TARGET "echo 'uid = swift' > /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'gid = swift' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'log file = /var/log/rsyncd.log' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'pid file = /var/run/rsyncd.pid' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'address = $TRAGET' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '\\n' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '[account]' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'max connections = 2' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'path = /srv/node/' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'read only = False' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'lock file = /var/lock/account.lock' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '\\n' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '[container]' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'max connections = 2' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'path = /srv/node/' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'read only = False' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'lock file = /var/lock/container.lock' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '\\n' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo '[object]' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'max connections = 2' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'path = /srv/node/' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'read only = False' >> /etc/rsyncd.conf"
    ssh root@$TARGET "echo 'lock file = /var/lock/object.lock' >> /etc/rsyncd.conf"

    ssh root@$TARGET "systemctl enable rsyncd.service"
    ssh root@$TARGET "systemctl start rsyncd.service"


    ssh root@$TARGET "yum -y --nogpgcheck install wget openstack-swift-account openstack-swift-container openstack-swift-object"

    ssh root@$TARGET "mkdir -p /etc/swift/"
    ssh root@$TARGET "curl -o /etc/swift/account-server.conf http://installer/install/openstack-config/account-server.conf"
	ssh root@$TARGET "curl -o /etc/swift/container-server.conf http://installer/install/openstack-config/container-server.conf"
	ssh root@$TARGET "curl -o /etc/swift/object-server.conf http://installer/install/openstack-config/object-server.conf"
	

	#/etc/swift/account-server.conf
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_ip = $SWIFTIP" ' /etc/swift/account-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_port = 6002" ' /etc/swift/account-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "user = swift" ' /etc/swift/account-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "swift_dir = /etc/swift" ' /etc/swift/account-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "devices = /srv/node" ' /etc/swift/account-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "mount_check = True" ' /etc/swift/account-server.conf"
	
	ssh root@$TARGET "sed -i '/^\[filter:recon\]/a "recon_cache_path = /var/cache/swift" ' /etc/swift/account-server.conf"
	
	#/etc/swift/container-server.conf
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_ip = $SWIFTIP" ' /etc/swift/container-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_port = 6001" ' /etc/swift/container-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "user = swift" ' /etc/swift/container-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "swift_dir = /etc/swift" ' /etc/swift/container-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "devices = /srv/node" ' /etc/swift/container-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "mount_check = True" ' /etc/swift/container-server.conf"
	
	ssh root@$TARGET "sed -i '/^\[filter:recon\]/a "recon_cache_path = /var/cache/swift" ' /etc/swift/container-server.conf"
	
	#/etc/swift/object-server.conf
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_ip = $SWIFTIP" ' /etc/swift/object-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "bind_port = 6000" ' /etc/swift/object-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "user = swift" ' /etc/swift/object-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "swift_dir = /etc/swift" ' /etc/swift/object-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "devices = /srv/node" ' /etc/swift/object-server.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "mount_check = True" ' /etc/swift/object-server.conf"
	
	ssh root@$TARGET "sed -i '/^\[filter:recon\]/a "recon_cache_path = /var/cache/swift" ' /etc/swift/object-server.conf"
	
	ssh root@$TARGET "chown -R swift:swift /srv/node"
	ssh root@$TARGET "mkdir -p /var/cache/swift"
	ssh root@$TARGET "chown -R root:swift /var/cache/swift"
	ssh root@$TARGET "chmod -R 775 /var/cache/swift"

	ssh root@$TARGET "chcon -R system_u:object_r:swift_data_t:s0 /srv/node"

	ssh root@$TARGET "systemctl enable openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
	ssh root@$TARGET "systemctl start openstack-swift-account.service openstack-swift-account-auditor.service \
  openstack-swift-account-reaper.service openstack-swift-account-replicator.service"
	ssh root@$TARGET "systemctl enable openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service"
	ssh root@$TARGET "systemctl start openstack-swift-container.service \
  openstack-swift-container-auditor.service openstack-swift-container-replicator.service \
  openstack-swift-container-updater.service"
	ssh root@$TARGET "systemctl enable openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service"
	ssh root@$TARGET "systemctl start openstack-swift-object.service openstack-swift-object-auditor.service \
  openstack-swift-object-replicator.service openstack-swift-object-updater.service"

  #/etc/swift/swift.conf
  ssh root@$TARGET "curl -o /etc/swift/swift.conf http://installer/install/openstack-config/swift.conf"
  ssh root@$TARGET "chown -R root:swift /etc/swift"
	

  

}

function init_swift_rings_on_controller
{
	TARGET=$1
	PASSWD=$2
	STORAGE_NODES=($3)

	ssh root@$TARGET "cd /etc/swift; swift-ring-builder account.builder create 10 3 1"
	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /etc/swift; swift-ring-builder account.builder \
  add --region 1 --zone 1 --ip $NODE --port 6002 \
  --device sdb --weight 100" 
	done
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder account.builder"
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder account.builder rebalance"


	ssh root@$TARGET "cd /etc/swift; swift-ring-builder container.builder create 10 3 1"
	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /etc/swift; swift-ring-builder container.builder \
  add --region 1 --zone 1 --ip $NODE --port 6001 \
  --device sdb --weight 100"
	done
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder container.builder"
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder container.builder rebalance"


	ssh root@$TARGET "cd /etc/swift; swift-ring-builder object.builder create 10 3 1"
	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /etc/swift; swift-ring-builder object.builder \
  add --region 1 --zone 1 --ip $NODE --port 6000 \
  --device sdb --weight 100"
	done
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder object.builder"
	ssh root@$TARGET "cd /etc/swift; swift-ring-builder object.builder rebalance"

	# todo : need to ssh-copy-id from $TARGET to $NODE
	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /etc/swift; scp account.ring.gz root@$NODE:/etc/swift"
		ssh root@$TARGET "cd /etc/swift; scp container.ring.gz root@$NODE:/etc/swift"
		ssh root@$TARGET "cd /etc/swift; scp object.ring.gz root@$NODE:/etc/swift"
	done
}