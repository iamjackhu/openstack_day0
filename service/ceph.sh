#!/bin/bash

function install_ceph_at_controller
{
	TARGET=$1
	STORAGE_NODES=($2)

	ssh root@$TARGET "subscription-manager repos --enable=rhel-7-server-extras-rpms"
	ssh root@$TARGET "yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"

	#### /etc/yum.repos.d/ceph.repo
	ssh root@$TARGET "echo '[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm-kraken/el7/x86_64
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
' > /etc/yum.repos.d/ceph.repo"

	ssh root@$TARGET "yum -y update; yum -y install ceph-deploy"

	ssh root@$TARGET "mkdir -p /root/ceph-cluster"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy purgedata $STORAGE_NODES"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy forgetkeys"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy new $STORAGE_NODES"
	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy osd prepare $NODE:/storage/ceph/osd"
		ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy osd activate $NODE:/storage/ceph/osd"
	done
	ssh root@$TARGET "ceph -w"

}

function install_ceph_at_storage
{
	TARGET=$1

	ssh root@$TARGET "yum install yum-plugin-priorities --enablerepo=rhel-7-server-optional-rpms"
}