#!/bin/bash

HOST=$1

source ./env

# ##### prepare
# source ./service/prepare.sh
# initial_host $HOST

# ##### controller
# source ./component/mysql.sh
# source ./component/rabbitmq.sh
# source ./component/memcached.sh

# install_mysql $HOST $mysql_root_passwd
# install_rabitmq $HOST $rabbit_passwd
# install_memcached $HOST

# source ./service/identity.sh
# install_identity $HOST $identity_passwd $mysql_root_passwd

# source ./service/glance.sh
# install_glance $HOST $glance_passwd $mysql_root_passwd ceph

# source ./service/compute.sh
# controller_my_ip=10.0.1.102
# install_compute_on_controller $HOST $compute_passwd $mysql_root_passwd $rabbit_passwd $controller_my_ip 

# source ./service/network.sh
# install_network_on_controller $HOST $network_passwd $mysql_root_passwd $rabbit_passwd $compute_passwd $controller_provider_interface $controller_my_ip 

# source ./service/swift.sh
# install_swift_on_controller $HOST $swift_passwd $HOST 10.0.3.102

# init_swift_rings_on_controller $HOST $swift_passwd "$storage1 $storage2 $storage3"

source ./service/heat.sh
install_heat_on_controller $HOST $heat_passwd $mysql_root_passwd $rabbit_passwd

# source ./service/cinder.sh
# install_cinder_on_controller $HOST $cinder_passwd $mysql_root_passwd $rabbit_passwd 10.0.1.102 ceph $rbd_uuid

# source ./service/dashboard.sh
# install_dashboard $HOST


