#!/usr/bin/env python3

from dateutil import parser as timeparser
from datetime import datetime, timezone, timedelta
from humanize import naturalsize, naturaldelta
import logging
import openstack
import sys
from pprint import pprint

def find_old_instances(aggregate=None, days=7, slots=52):
    log = logging.getLogger('find_old_instances')

    log.info(f"find_old_instances started")

    conn = openstack.connect()

    log.debug(f"Connected to OpenStack API")

    aggregates = {x.name: x for x in conn.compute.aggregates() if aggregate is None or aggregate == x.name}
    projects = {x.id: x for x in conn.identity.projects()}
    flavors = {x.id: x for x in conn.compute.flavors(details=True)}
    flavors.update({x.id: x for x in conn.compute.flavors(details=True, is_public=False)})

    ram_usage = [0, ] * slots

    #pprint(flavors)

    for aggr_name, aggr in aggregates.items():
        log.debug(f"Checking aggregate {aggr_name}")
        for host in aggr.hosts:
            log.debug(f"Checking {host}")
            for server in conn.compute.servers(all_projects=True, details=True, host=host):
                age = datetime.now(timezone.utc) - timeparser.parse(server.created_at)
                try:
                    ram = flavors[server.flavor['id']].ram
                    slot = min(round(age.total_seconds() / (days * 24 * 60 * 60)), slots-1)
                    ram_usage[slot] += ram
                except KeyError:
                    log.warn(f"Server {server.id} is using an unknown flavor ({server.flavor['id']})")

    #pprint(server)
    #pprint(old_servers)
    #pprint(old_ram)
    #pprint(old_score)

    tot_ram = sum(ram_usage)
    max_ram = max(ram_usage)
    max_bar_width = 50
    scale = max_bar_width * 1.0 / max_ram
    for i, ram in enumerate(ram_usage):
        bar_width = round(ram*scale)
        log.info(f"{(i+1)*days:4d}: {'*'*bar_width}{' '*(max_bar_width-bar_width)} {naturalsize(ram*1024*1024, binary=True)}")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Find long running instances")
    parser.add_argument("-a", "--aggregate", help="Aggregate to be examined")
    parser.add_argument("-i", "--interval", help="Histogram resolution [days]", type=int, default=7)
    parser.add_argument("-s", "--slots", help="Number of bars", type=int, default=52)
    parser.add_argument("-v", "--verbose", help="Increase output verbosity", action="count", default=0)
    opts = parser.parse_args()

    logging.basicConfig(format="%(asctime)s %(name)s %(levelname)s: %(message)s")

    verbosity = {
        0: logging.WARN,
        1: logging.INFO,
        2: logging.DEBUG
    }.get(opts.verbose, logging.DEBUG)

    logging.getLogger('find_old_instances').setLevel(verbosity)

    find_old_instances(aggregate=opts.aggregate, days=opts.interval, slots=opts.slots)

# vim:et:sts=4:sw=4
