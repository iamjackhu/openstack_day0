#!/bin/bash

function initial_host
{
	TARGET=$1
	ssh root@$TARGET 'yum -y update'
	ssh root@$TARGET 'yum install -y https://rdoproject.org/repos/rdo-release.rpm'
	ssh root@$TARGET 'yum -y upgrade'
}