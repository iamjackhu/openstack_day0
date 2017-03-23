#!/bin/bash

function install_ceph_at_controller
{
	TARGET=$1
	STORAGE_NODES=($2)
	
	#### /etc/yum.repos.d/ceph.repo
	ssh root@$TARGET "echo '[Ceph]
name=Ceph packages for $basearch
baseurl=http://hk.ceph.com/rpm-jewel/el7/x86_64
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://hk.ceph.com/rpm-jewel/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://hk.ceph.com/rpm-jewel/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1
' > /etc/yum.repos.d/ceph.repo"

	ssh root@$TARGET "yum -y update; yum -y install ceph-deploy ceph"

	ssh root@$TARGET "yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"

	for NODE in ${STORAGE_NODES[@]} 
	do
		install_ceph_at_storage $NODE
		echo "##### $NODE install completed!  ######"
	done
	
	ssh root@$TARGET "mkdir -p /root/ceph-cluster"
	# ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy purgedata $STORAGE_NODES"
	# ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy forgetkeys"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy new $STORAGE_NODES"
	ssh root@$TARGET "echo 'osd pool default size = 2
public network = 10.0.1.0/24
cluster network = 10.0.3.0/24
' >> /root/ceph-cluster/cepf.conf"
	# ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy install $STORAGE_NODES"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy mon create-initial"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy gatherkeys $STORAGE_NODES"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy admin $STORAGE_NODES $TARGET"
	ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy mds create $TARGET"

	for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy osd prepare $NODE:/dev/sdb"
		#### /usr/sbin/ceph-disk -v prepare --cluster ceph --fs-type xfs -- /dev/sdb
		ssh root@$TARGET "cd /root/ceph-cluster;ceph-deploy osd activate $NODE:/dev/sdb"
		#### /usr/sbin/ceph-disk -v activate --mark-init systemd --mount /dev/sdb
		ssh root@$NODE "chmod 644 /etc/ceph/ceph.client.admin.keyring"
		echo "##### $NODE setting completed!  ######"
	done

	ssh root@$TARGET "ceph osd pool create volumes 128"
	ssh root@$TARGET "ceph osd pool create images 128"
	ssh root@$TARGET "ceph osd pool create backups 128"	
	ssh root@$TARGET "ceph osd pool create vms 128"	

	ssh root@$TARGET "ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rx pool=images' "
	ssh root@$TARGET "ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images' "
	ssh root@$TARGET "ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups' "

    for NODE in ${STORAGE_NODES[@]} 
	do
		ssh root@$NODE "echo '<secret ephemeral=\'no\' private=\'no\'>
  <uuid>8033ef86-0be1-11e7-93ae-92361f002671</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>' > secret.xml"

		ssh root@$NODE "virsh secret-set-value --secret 8033ef86-0be1-11e7-93ae-92361f002671 --base64 $(ceph auth get-key client.cidner)"
		ssh root@$NODE "mkdir /var/run/ceph/guests/ /var/log/qemu/"
		ssh root@$NODE "chmod 777 /var/run/ceph/guests/ /var/log/qemu/"
		ssh root@$NODE "systemctl restart libvirtd.service openstack-nova-compute.service"
	done 

	ssh root@$TARGET "ceph -s"

}

function install_ceph_at_storage
{
	TARGET=$1

	ssh root@$TARGET "echo '[Ceph]
name=Ceph packages for $basearch
baseurl=http://hk.ceph.com/rpm-jewel/el7/x86_64
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[Ceph-noarch]
name=Ceph noarch packages
baseurl=http://hk.ceph.com/rpm-jewel/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1

[ceph-source]
name=Ceph source packages
baseurl=http://hk.ceph.com/rpm-jewel/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
priority=1
' > /etc/yum.repos.d/ceph.repo"

	ssh root@$TARGET "yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"

	ssh root@$TARGET "yum -y update; yum -y install ceph ceph-radosgw"

	

}