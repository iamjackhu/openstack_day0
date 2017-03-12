#!/bin/bash

HOST=$1
SWIFTIP=$2

source ./env

# #### prepare
# source ./service/prepare.sh
# initial_host $HOST

# ###### swift
# source ./service/swift.sh
# install_swift_on_storage $HOST $swift_passwd $SWIFTIP

source ./service/cinder.sh
install_cinder_on_storage $HOST $cinder_passwd $mysql_root_passwd $rabbit_passwd 10.0.1.103 node2

