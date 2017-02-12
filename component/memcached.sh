#!/bin/bash



function install_memcached
{
	TARGET=$1
	ssh root@$TARGET "yum -y install memcached python-memcached"
	ssh root@$TARGET "systemctl enable memcached.service"
	ssh root@$TARGET "systemctl start memcached.service"

	echo "### Memcached installed"
}