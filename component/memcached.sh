#!/bin/bash



function install_memcached
{
	TARGET=$1
	ssh root@$TARGET "yum -y install memcached python-memcached"

	### change localhost to 0.0.0.0
	ssh root@$TARGET "sed -i -e 's/127.0.0.1/0.0.0.0/g' /etc/sysconfig/memcached "

	ssh root@$TARGET "systemctl enable memcached.service"
	ssh root@$TARGET "systemctl start memcached.service"

	echo "### Memcached installed"
}