#!/bin/bash

HOST=$1

source ./env

##### prepare
source ./service/ceph.sh
install_ceph_at_controller $HOST "node3 node4 node5"