#!/bin/bash

TARGET=$1

ssh root@$TARGET ". adminrc;openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano"
ssh root@$TARGET ". adminrc;openstack keypair create --public-key ~/.ssh/id_rsa.pub mykey"

ssh root@$TARGET ". adminrc;openstack network create  --share \
  --provider-physical-network provider \
  --provider-network-type flat provider"

ssh root@$TARGET "openstack subnet create --network provider \
  --allocation-pool start=10.1.0.2,end=10.1.0.254 \
  --dns-nameserver 8.8.4.4 --gateway 10.1.0.1 \
  --subnet-range 10.1.0.0/24 provider"

ssh root@$TARGET ". adminrc;openstack security group rule create --proto icmp default"
ssh root@$TARGET ". adminrc;openstack security group rule create --proto tcp --dst-port 22 default"

ssh root@$TARGET "wget http://installer/install/cirros-0.3.5-x86_64-disk.img"
ssh root@$TARGET ". adminrc;openstack image create cirros \
  --file cirros-0.3.5-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public"

ssh root@$TARGET "openstack server create --flavor m1.nano --image cirros \
  --nic net-id=provider --security-group default \
  --key-name mykey provider-instance1"

ssh root@$TARGET ". adminrc;openstack volume create --size 1 volume1"