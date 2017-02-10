#!/bin/bash

HOST=$1
PASSWD=$2

source ./env

source ./prepare.sh
initial_host $HOST

#controller
source ./controller.sh
install_mysql $HOST $mysql_root_passwd
install_rabitmq $HOST $rabbit_passwd
install_memcached $HOST