#!/bin/bash -e
# Creates some instances for networking-sfc demo/development:
# a web server, another instance to use as client
# three "service VMs" with two interfaces that will just route the packets to/from each interface

. $(dirname "${BASH_SOURCE}")/custom.sh
. $(dirname "${BASH_SOURCE}")/tools.sh

# Disable port security (This allow spoofing just to make possible the ip forwarding)
openstack network set --disable-port-security private

# Create ports for all VMs
for port in p1in p1out p2in p2out p3in p3out source_port dest_port
do
    openstack port create --network private "${port}"
done

# SFC VMs
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p1in)" \
    --nic port-id="$(openstack port show -f value -c id p1out)" \
     vm1
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p2in)" \
    --nic port-id="$(openstack port show -f value -c id p2out)" \
     vm2
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id p3in)" \
    --nic port-id="$(openstack port show -f value -c id p3out)" \
     vm3

# Demo VMs
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id source_port)" \
     source_vm
openstack server create --image "${IMAGE}" --flavor "${FLAVOR}" \
    --nic port-id="$(openstack port show -f value -c id dest_port)" \
     dest_vm

# Floating IPs
SOURCE_FLOATING=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip source_vm ${SOURCE_FLOATING}
DEST_FLOATING=$(openstack floating ip create public -f value -c floating_ip_address)
openstack server add floating ip dest_vm ${DEST_FLOATING}
for i in 1 2 3; do
    floating_ip=$(openstack floating ip create public -f value -c floating_ip_address)
    declare VM${i}_FLOATING=${floating_ip}
    openstack server add floating ip vm${i} ${floating_ip}
done

# HTTP Flow classifier (catch the web traffic from source_vm to dest_vm)
SOURCE_IP=$(openstack port show source_vm_port -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
DEST_IP=$(openstack port show dest_vm_port -f value -c fixed_ips | grep "ip_address='[0-9]*\." | cut -d"'" -f2)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol tcp \
    --destination-port 80:80 \
    --logical-source-port source_port \
    FC_http

# UDP flow classifier (catch all UDP traffic from source_vm to dest_vm, like traceroute)
neutron flow-classifier-create \
    --ethertype IPv4 \
    --source-ip-prefix ${SOURCE_IP}/32 \
    --destination-ip-prefix ${DEST_IP}/32 \
    --protocol udp \
    --logical-source-port source_port \
    FC_udp

# Get easy access to the VMs (single node)
route_to_subnetpool

# Create the port pairs for all 3 VMs
neutron port-pair-create --ingress=p1in --egress=p1out PP1
neutron port-pair-create --ingress=p2in --egress=p2out PP2
neutron port-pair-create --ingress=p3in --egress=p3out PP3

# And the port pair groups
neutron port-pair-group-create --port-pair PP1 --port-pair PP2 PG1
neutron port-pair-group-create --port-pair PP3 PG2

# The complete chain
neutron port-chain-create --port-pair-group PG1 --port-pair-group PG2 --flow-classifier FC_udp --flow-classifier FC_http PC1

# Start a basic demo web server
ssh cirros@${DEST_FLOATING} 'while true; do echo -e "HTTP/1.0 200 OK\r\n\r\nWelcome to $(hostname)" | sudo nc -l -p 80 ; done&'

# On service VMs, enable eth1 interface and add static routing
for i in 1 2 3
do
    ip_name=VM${i}_FLOATING
    ssh -T cirros@${!ip_name} <<EOF
sudo sh -c 'echo "auto eth1" >> /etc/network/interfaces'
sudo sh -c 'echo "iface eth1 inet dhcp" >> /etc/network/interfaces'
sudo /etc/init.d/S40network restart
sudo sh -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
sudo ip route add ${SOURCE_IP} dev eth0
sudo ip route add ${DEST_IP} dev eth1

EOF
done
