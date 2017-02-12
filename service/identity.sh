#!/bin/bash


function install_identity
{
	TARGET=$1
	PASSWD=$2
	MYSQLPASSWD=$3

	ssh root@$TARGET "mysql -e \"CREATE DATABASE keystone;\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON keystone.* TO keystone@'localhost' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"
	ssh root@$TARGET "mysql -e \"GRANT ALL PRIVILEGES ON keystone.* TO keystone@'%' IDENTIFIED BY '$PASSWD';\" -u root -p<<EOF
$MYSQLPASSWD
EOF"

	ssh root@$TARGET "yum -y install openstack-keystone httpd mod_wsgi python-openstackclient"

    #  /etc/keystone/keystone.conf
    ssh root@$TARGET "sed -i '/\[database\]/a "connection = mysql+pymysql://keystone:$PASSWD@$TARGET/keystone" ' /etc/keystone/keystone.conf"
    ssh root@$TARGET "sed -i '/\[token\]/a "provider = fernet" ' /etc/keystone/keystone.conf"
    ssh root@$TARGET "su -s /bin/sh -c \"keystone-manage db_sync\" keystone"
    ssh root@$TARGET "keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone"
    ssh root@$TARGET "keystone-manage credential_setup --keystone-user keystone --keystone-group keystone"

    ssh root@$TARGET "keystone-manage bootstrap --bootstrap-password $PASSWD \
  --bootstrap-admin-url http://$TARGET:35357/v3/ \
  --bootstrap-internal-url http://$TARGET:35357/v3/ \
  --bootstrap-public-url http://$TARGET:5000/v3/ \
  --bootstrap-region-id RegionOne"

  	ssh root@$TARGET "sed -i '/#ServerName/a "ServerName $TARGET" ' /etc/httpd/conf/httpd.conf"
  	ssh root@$TARGET "ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/"
  	ssh root@$TARGET "systemctl enable httpd.service"
  	ssh root@$TARGET "systemctl start httpd.service"

    ssh root@$TARGET "echo 'export OS_USERNAME=admin' > /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_PASSWORD=$PASSWD' >> /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_PROJECT_NAME=admin' >> /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_USER_DOMAIN_NAME=Default' >> /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_PROJECT_DOMAIN_NAME=Default' >> /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_AUTH_URL=http://$TARGET:35357/v3' >> /tmp/initrc"
    ssh root@$TARGET "echo 'export OS_IDENTITY_API_VERSION=3' >> /tmp/initrc"

  ssh root@$TARGET "source /tmp/initrc"

	ssh root@$TARGET "source /tmp/initrc;openstack project create --domain default --description 'Service Project' service"
	ssh root@$TARGET "source /tmp/initrc;openstack project create --domain default --description 'Demo Project' demo"
	ssh root@$TARGET "source /tmp/initrc;openstack user create --domain default --password demo demo"
	ssh root@$TARGET "source /tmp/initrc;openstack role create user"
	ssh root@$TARGET "source /tmp/initrc;openstack role add --project demo --user demo user"

	ssh root@$TARGET "echo -e \"export OS_PROJECT_DOMAIN_NAME=Default\n\
export OS_USER_DOMAIN_NAME=Default\n\
export OS_PROJECT_NAME=admin\n\
export OS_USERNAME=admin\n\
export OS_PASSWORD=$PASSWD\n\
export OS_AUTH_URL=http://$TARGET:35357/v3\n\
export OS_IDENTITY_API_VERSION=3\n\
export OS_IMAGE_API_VERSION=2\n\
\" > /root/adminrc"

ssh root@$TARGET "echo -e \"export OS_PROJECT_DOMAIN_NAME=Default\n\
export OS_USER_DOMAIN_NAME=Default\n\
export OS_PROJECT_NAME=demo\n\
export OS_USERNAME=demo\n\
export OS_PASSWORD=demo\n\
export OS_AUTH_URL=http://$TARGET:5000/v3\n\
export OS_IDENTITY_API_VERSION=3\n\
export OS_IMAGE_API_VERSION=2\n\
\" > /root/demo-openrc"

  ssh root@$TARGET "sed -i 's/ admin_token_auth / /g' /etc/keystone/keystone-paste.ini"
  ssh root@$TARGET "systemctl restart httpd.service"

  echo "### Keystone installed"

}