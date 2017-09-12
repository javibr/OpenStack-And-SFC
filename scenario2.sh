#!/bin/bash -e
# Creates some instances for networking-sfc demo/development:
# a web server, another instance to use as client
# three "service VMs" with two interfaces that will just route the packets to/from each interface

. $(dirname "${BASH_SOURCE}")/options.sh
. $(dirname "${BASH_SOURCE}")/route.sh

# Disable port security (This allow spoofing just to make possible the ip forwarding)
openstack network set --disable-port-security private

# Create ports for all VMs
for port in p1in p1out p2in p2out p3in p3out s1 s2 dest_port
do
    openstack port create --network private "${port}"
done

# SFC VMs
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id p1in)" \
    --nic port-id="$(openstack port show -f value -c id p1out)" \
     vm1
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id p2in)" \
    --nic port-id="$(openstack port show -f value -c id p2out)" \
     vm2
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id p3in)" \
    --nic port-id="$(openstack port show -f value -c id p3out)" \
     vm3

openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id s1)" \
     s1
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id s2)" \
     s2
openstack server create --image cirros-0.3.5-x86_64-disk --flavor m1.nano \
    --nic port-id="$(openstack port show -f value -c id dest_port)" \
     dest_vm

# Floating IPs
SOURCE_FLOATING1=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip s1 ${SOURCE_FLOATING1}

SOURCE_FLOATING2=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip s2 ${SOURCE_FLOATING2}

DEST_FLOATING=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip dest_vm ${DEST_FLOATING}
for i in 1 2 3; do
    floating_ip=$(openstack floating ip create public -f value -c floating_ip_address)
    declare VM${i}_FLOATING=${floating_ip}
    openstack server add floating ip vm${i} ${floating_ip}
done

# Create the port pairs for all 3 VMs
neutron port-pair-create --ingress=p1in --egress=p1out PPA
neutron port-pair-create --ingress=p2in --egress=p2out PPB
neutron port-pair-create --ingress=p3in --egress=p3out PPC

# And the port pair groups
neutron port-pair-group-create --port-pair PPA --port-pair PPB PGA
neutron port-pair-group-create --port-pair PPC PGB

# HTTP Flow classifier (web traffic from source to destination)
SOURCE_IP1=$(openstack port show s1 -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
SOURCE_IP2=$(openstack port show s2 -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
DEST_IP=$(openstack port show dest_port -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix 10.0.0.0/24 \
    --destination-ip-prefix 10.0.0.0/24 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port s1 \
    http1
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix 10.0.0.0/24 \
    --destination-ip-prefix 10.0.0.0/24 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port s2 \
    http2

# UDP flow classifier (UDP traffic)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix 10.0.0.0/24 \
    --destination-ip-prefix 10.0.0.0/24 \
    --protocol udp \
    --logical-source-port s1 \
    udp1
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix 10.0.0.0/24 \
    --destination-ip-prefix 10.0.0.0/24 \
    --protocol udp \
    --logical-source-port s2 \
    udp2

# Get easy access to the VMs (single node)
VM_route

# The complete chain
neutron port-chain-create --port-pair-group PGA --port-pair-group PGB --flow-classifier udp1  --flow-classifier udp2 \
 --flow-classifier http1 --flow-classifier http2  PCA

# Start a basic demo web server
sshpass -p "cubswin:)" ssh cirros@${DEST_IP} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to my home" | sudo nc -l -p 80 ; done&'

# On service VMs, enable eth1 interface and add static routing
for i in 1 2 3
do
    ip_name=VM${i}_FLOATING
sshpass -p "cubswin:)" ssh -T cirros@${!ip_name}<<EOF
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo /etc/init.d/S40network restart
sudo ip route add ${SOURCE_IP1} dev eth0
sudo ip route add ${SOURCE_IP2} dev eth0
sudo ip route add ${DEST_IP} dev eth1
exit
EOF
done