#!/bin/bash

HOST=$1
MY_IP=$2
CONTROLLER=$3

source ./env

# #### prepare
# source ./service/prepare.sh
# initial_host $HOST

# ###### cinder
source ./service/cinder.sh
STORAGETYPE=ceph
install_cinder_on_storage $HOST $cinder_passwd $mysql_root_passwd $rabbit_passwd $MY_IP $CONTROLLER $STORAGETYPE $rbd_uuid

