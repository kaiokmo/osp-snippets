#!/bin/bash

subnets=$(mysql ovs_neutron -e "select id from subnets" | tail -n+2)
for subnet_id in $subnets; do
    echo "Fixing subnet $subnet_id"
    allocated_ips=$(mysql ovs_neutron -e "select ip_address from ipallocations where subnet_id='$subnet_id'" | tail -n+2)
    subnet_ipam=$(mysql ovs_neutron -e "select id from ipamsubnets where neutron_subnet_id='$subnet_id' limit 1" | tail -n+2)
    mysql ovs_neutron -e "select ip_address from ipamallocations where ipam_subnet_id='$subnet_ipam'" | tail -n+2 > /tmp/allocated.txt

    for ip_addr in $allocated_ips; do
        if ! grep -q $ip_addr /tmp/allocated.txt; then
           echo "fixing $ip_addr"
           mysql ovs_neutron -e "insert into ipamallocations (ip_address, status, ipam_subnet_id) values ('$ip_addr', 'ALLOCATED', '$subnet_ipam')"
        fi
    done
    echo
done
