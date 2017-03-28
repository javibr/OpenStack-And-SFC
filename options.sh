#!/bin/bash -e
# Basic configuration of the devstack
# Credentials, SSH keys, security group

# If you want to use your own SSH key (with forwarding agent)
#CUSTOM_SSH_KEYNAME="defiant"
#CUSTOM_SSH_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIxK0j9EvqUDndkB8h+MKA6TqNstTyw66VVBuMVywqYxtH73qOzzBjSNIAlO1nT7zL2BBN3kQNL84nmbGevwckB+lzIZrc+Tzc2a1VhopthemftZw0XUnn6+uf8UU4K9d17434u/U12F3ZDOprJypmr9xOOy0zrX09ycZqMrs0B5QoZb6zCP5FzZTo8qGL0sB01zAyYgxw5u+RK8bpNGfTXJ5lakXfdVdB71Pubu1FybIqgR9vIg46FkygMZygT33jUt5pOGKddG++/4t0fHSv21OgXfFb6HNZHDFELY5b8hBRZmuQ+vMpvu+gsD5IabLj3B/rAwtgulCN/gCHqgxR bcafarel@defiant.redhat.com"
#SSH_KEYNAME=${CUSTOM_SSH_KEYNAME}

# Else use local key (will be generated if it does not exist)
SSH_KEYNAME="default"
# Use nano or tiny flavor
FLAVOR=m1.nano
# Cirros image modified with tcpdump
IMAGE=disk-1

# Source credentials (devstack, packstack, tripleo)
PROJECT="demo" # tripleo uses admin project
if [[ -e ~/devstack/openrc ]]; then
    echo "Sourcing devstack ${PROJECT} credentials"
    source ~/devstack/openrc "${PROJECT}" "${PROJECT}"
elif [[ -e ~/keystonerc_${PROJECT} ]]; then
    echo "Sourcing packstack ${PROJECT} credentials"
    source ~/keystonerc_${PROJECT}
elif [[ -e ~/overcloudrc ]]; then
    echo "Sourcing overcloud credentials"
    echo "WARNING: not fully suppported yet"
    source ~/overcloudrc
    openstack network show public 2>/dev/null || $(dirname "${BASH_SOURCE}")/overcloud_basic_setup.sh
else
    echo "Problem retrieving credentials file"
    exit 1
fi

# Use nano or tiny flavor
FLAVOR=m1.nano
# Find cirros image
IMAGE=disk-1

# Note: check on existing rules is basic
SECGROUP=$(openstack security group list -f value -c ID --project admin 2> /dev/null || echo default)
SECGROUP_RULES=$(openstack security group show "${SECGROUP}" -f value -c rules)
if ! echo "${SECGROUP_RULES}" | grep -q icmp
then
    openstack security group rule create --proto icmp "${SECGROUP}"
fi
for port in 22 80
do
    if ! echo "${SECGROUP_RULES}" | grep -q "port_range_max='${port}', port_range_min='${port}'"
    then
        openstack security group rule create --proto tcp --dst-port ${port} "${SECGROUP}"
    fi 
done
