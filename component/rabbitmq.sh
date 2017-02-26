#!/bin/bash

function install_rabitmq
{
	TARGET=$1
	PASSWD=$2
	ssh root@$TARGET "yum -y install rabbitmq-server"
	ssh root@$TARGET "systemctl enable rabbitmq-server.service"
	ssh root@$TARGET "systemctl start rabbitmq-server.service"
	ssh root@$TARGET "rabbitmqctl add_user openstack $PASSWD"
	ssh root@$TARGET "rabbitmqctl set_permissions openstack \".*\" \".*\" \".*\" "

	

	echo "### RabbitMQ installed"
}