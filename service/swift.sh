#!/bin/bash

function install_swift_on_controller
{
	TARGET=$1
	PASSWD=$2

	ssh root@$TARGET ". adminrc"
	
}

function install_swift_on_storage
{
	TARGET=$1
	
}