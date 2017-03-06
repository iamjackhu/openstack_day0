#!/bin/bash

function getHostIP
{
	$host_name=$1
	host_ip=`/usr/bin/hostname -i`
	return $host_ip
}

function initial_host
{
	TARGET=$1

	ssh root@$TARGET "echo 'export LC_ALL=en_US.UTF-8' >> /root/.bashrc"
	ssh root@$TARGET "echo 'export LANG=en_US.UTF-8' >> /root/.bashrc"

	ssh root@$TARGET 'yum -y update'
	ssh root@$TARGET 'yum install -y https://repos.fedorapeople.org/repos/openstack/openstack-newton/rdo-release-newton-4.noarch.rpm'
	# ssh root@$TARGET "sed -i -e 's/ocata/newton/g' /etc/yum.repos.d/rdo-release.repo "
	# ssh root@$TARGET "sed -i -e 's/ocata/newton/g' /etc/yum.repos.d/rdo-testing.repo "
	# ssh root@$TARGET "sed -i -e 's/ocata/newton/g' /etc/yum.repos.d/rdo-qemu-ev.repo "
	ssh root@$TARGET 'yum -y upgrade'
	ssh root@$TARGET 'yum -y install wget'

	# ssh root@$TARGET 'yum -y install yum-utils'
	# ssh root@$TARGET 'yum -y install deltarpm'
	# ssh root@$TARGET 'rm -rf /etc/yum.repos.d/*'
	# ssh root@$TARGET 'yum-config-manager --add-repo http://installer/install/repo'
	# ssh root@$TARGET 'yum-config-manager --enable installer_install_repo'
	# ssh root@$TARGET 'echo "gpgcheck=0" >> /etc/yum.repos.d/installer_install_repo.repo'
	# ssh root@$TARGET 'yum-config-manager --add-repo http://installer/install/extras'
	# ssh root@$TARGET 'yum-config-manager --enable installer_install_extras'
	# ssh root@$TARGET 'echo "gpgcheck=0" >> /etc/yum.repos.d/installer_install_extras.repo'
	# ssh root@$TARGET 'yum-config-manager --add-repo http://installer/install/openstack-newton-repo'
	# ssh root@$TARGET 'yum-config-manager --enable installer_install_openstack-newton-repo'
	# ssh root@$TARGET 'echo "gpgcheck=0" >> /etc/yum.repos.d/installer_install_openstack-newton-repo.repo'
	# ssh root@$TARGET 'yum-config-manager --add-repo http://installer/install/kvm-common-repo'
	# ssh root@$TARGET 'yum-config-manager --enable installer_install_kvm-common-repo'
	# ssh root@$TARGET 'echo "gpgcheck=0" >> /etc/yum.repos.d/installer_install_kvm-common-repo.repo'
	# ssh root@$TARGET 'yum clean all'
	# ssh root@$TARGET 'yum -y update'
	# ssh root@$TARGET 'yum -y upgrade'
}