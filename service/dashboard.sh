#!/bin/bash

function install_dashboard
{
	TARGET=$1

	ssh root@$TARGET "yum -y install openstack-dashboard"

	ssh root@$TARGET "sed -i 's/OPENSTACK_HOST = \"127.0.0.1\"/OPENSTACK_HOST = \"$TARGET\"/g ' /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i \"/ALLOWED_HOSTS/c\ALLOWED_HOSTS = ['*', ]\" /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i 's/django.core.cache.backends.locmem.LocMemCache/django.core.cache.backends.memcached.MemcachedCache/g ' /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i '/django.core.cache.backends.memcached.MemcachedCache/a "            \"LOCATION\": \"localhost:11211\", " ' /etc/openstack-dashboard/local_settings"
    
    ssh root@$TARGET "sed -i 's/http:\/\/%s:5000\/v2.0/http:\/\/%s:5000\/v3/g ' /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i '/#OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT/a "OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True" ' /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i '/#OPENSTACK_KEYSTONE_DEFAULT_DOMAIN/a "OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"default\"" ' /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "sed -i 's/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"_member_\"/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/g ' /etc/openstack-dashboard/local_settings"

    ssh root@$TARGET "echo -e \"SESSION_ENGINE = 'django.contrib.sessions.backends.cache'\" >> /etc/openstack-dashboard/local_settings"
    ssh root@$TARGET "echo -e \"OPENSTACK_API_VERSIONS = {\"identity\": 3,\"image\": 2,\"volume\": 2,}\" >> /etc/openstack-dashboard/local_settings"

	ssh root@$TARGET "systemctl restart httpd.service memcached.service"
}