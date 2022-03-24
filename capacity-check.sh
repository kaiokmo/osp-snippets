#!/bin/sh

proxy="<PROXY_FQDN>"
host=<ZABBIX_HOST>
port=10051

source openstackrc-file


(for aggregate in a b c d e; do
    result=$(for hv in $(openstack aggregate show $aggregate -f json -c hosts | jq -r .hosts[] | xargs -n1 -P10 openstack compute service list --service nova-compute -f value -c Host -c Status -c State --host | awk '$2=="enabled" && $3=="up" {print $1}' | sort | sed 's/.localdomain//g') ; do rp=$(openstack resource provider list | grep "$hv" | awk '{print $2}') ; ram_used=$(openstack resource provider usage show $rp -f value | grep ^MEMORY_MB | cut -d' ' -f2) ; ram_total=$(openstack resource provider inventory list $rp -f value -c resource_class -c total | grep ^MEMORY_MB | cut -d' ' -f2) ; echo $hv $ram_total $((8000+$ram_used)) "$((100*(8000+$ram_used)/$ram_total))%" ; done | awk '{inventory+=$2; usage+=$3; print $0} END {print (100*usage/inventory)}' | tail -n 1);

    key=$aggregate-ram-usage;
    /bin/zabbix_sender -z $proxy -p $port -s $host -k $key -o $result;
done;) &

wait
date
