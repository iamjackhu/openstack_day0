#!/bin/bash

HOST=$1
CONTROLLER=$2

source ./env

#prepare
source ./service/prepare.sh
initial_host $HOST

#compute
source ./service/compute.sh
install_compute_on_computer $HOST $compute_passwd $rabbit_passwd $CONTROLLER

source ./service/network.sh
install_network_on_computer $HOST $network_passwd $CONTROLLER $rabbit_passwd $compute_passwd $computer_provider_interface
