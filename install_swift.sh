#!/bin/bash

HOST=$1
CONTROLLER=$2

source ./env

#prepare
source ./service/prepare.sh
initial_host $HOST

#swift
source ./service/swift.sh
install_swift_on_storage $HOST $swift_passwd 

