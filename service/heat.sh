#!/bin/bash

function install_heat_on_controller
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3
	RABBIT_PASSWD=$4

	ssh root@$TARGET "mysql -e \"CREATE DATABASE heat;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON heat.* TO heat@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON heat.* TO heat@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET ". adminrc;openstack user create --domain default --password $PASSWD heat"

	ssh root@$TARGET ". adminrc;openstack role add --project service --user heat admin"
	ssh root@$TARGET ". adminrc;openstack service create --name heat --description \"Orchestration\" orchestration"
	ssh root@$TARGET ". adminrc;openstack service create --name heat-cfn --description \"Orchestration\" cloudformation"

	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne orchestration public http://$TARGET:8004/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne orchestration internal http://$TARGET:8004/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne orchestration admin http://$TARGET:8004/v1/%\(tenant_id\)s"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne cloudformation public http://$TARGET:8000/v1"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne cloudformation internal http://$TARGET:8000/v1"
	ssh root@$TARGET ". adminrc;openstack endpoint create --region RegionOne cloudformation admin http://$TARGET:8000/v1"

	ssh root@$TARGET ". adminrc;openstack domain create --description \"Stack projects and users\" heat"
	ssh root@$TARGET ". adminrc;openstack user create --domain heat --password $PASSWD heat_domain_admin"
	ssh root@$TARGET ". adminrc;openstack role add --domain heat --user-domain heat --user heat_domain_admin admin"
	ssh root@$TARGET ". adminrc;openstack role create heat_stack_owner"
	ssh root@$TARGET ". adminrc;openstack role add --project demo --user demo heat_stack_owner"
	ssh root@$TARGET ". adminrc;openstack role create heat_stack_user"
	
	ssh root@$TARGET "yum -y install openstack-heat-api openstack-heat-api-cfn openstack-heat-engine"

	###/etc/heat/heat.conf
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "transport_url = rabbit://openstack:$RABBIT_PASSWD@$TARGET" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "heat_metadata_server_url = http://$TARGET:8000" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "heat_waitcondition_server_url = http://$TARGET:8000/v1/waitcondition" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "stack_domain_admin = heat_domain_admin" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "stack_domain_admin_password = $PASSWD" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[DEFAULT\]/a "stack_user_domain_name = heat" ' /etc/heat/heat.conf"
	
  	ssh root@$TARGET "sed -i '/^\[database\]/a "connection = mysql+pymysql://heat:$PASSWD@$TARGET/heat" ' /etc/heat/heat.conf"

	ssh root@$TARGET "echo \"[keystone_authtoken]\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"auth_uri = http://$TARGET:5000\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"auth_url = http://$TARGET:35357\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"memcached_servers = $TARGET:11211\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"auth_type = password\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"project_domain_name = Default\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"user_domain_name = Default\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"project_name = service\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"username = heat\" >> /etc/heat/heat.conf"
	ssh root@$TARGET "echo \"password = $PASSWD\" >> /etc/heat/heat.conf"

	ssh root@$TARGET "sed -i '/^\[trustee\]/a "auth_url = http://$TARGET:35357\\n\
auth_type = password\\n\
user_domain_name = Default\\n\
username = heat\\n\
password = $PASSWD" ' /etc/heat/heat.conf"

	ssh root@$TARGET "sed -i '/^\[clients_keystone\]/a "auth_uri = http://$TARGET:35357" ' /etc/heat/heat.conf"
	ssh root@$TARGET "sed -i '/^\[ec2authtoken\]/a "auth_uri = http://$TARGET:5000" ' /etc/heat/heat.conf"

	ssh root@$TARGET "su -s /bin/sh -c \"heat-manage db_sync\" heat"

	ssh root@$TARGET "systemctl enable openstack-heat-api.service \
  openstack-heat-api-cfn.service openstack-heat-engine.service"
  	ssh root@$TARGET "systemctl restart openstack-heat-api.service \
  openstack-heat-api-cfn.service openstack-heat-engine.service"

  	### verify
  	ssh root@$TARGET ". adminrc;openstack orchestration service list"

}