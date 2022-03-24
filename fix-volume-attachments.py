#!/usr/bin/env python3

import logging
import openstack


def fix_attachments(instance):
    log = logging.getLogger('fix_attachments')

    log.info(f"Fix-attachments started")

    conn = openstack.connect()

    log.debug(f"Connected to OpenStack API")

    server = conn.compute.get_server(instance)
    log.debug(f"Server is {server.status} on {server.compute_host} ({server.hypervisor_hostname})")

    volumes = [conn.block_storage.get_volume(v['id']) for v in server.attached_volumes]
    for v in volumes:
        attachments = {a['attachment_id']: a['host_name'] for a in v['attachments'] if a['server_id'] == server.id and a['volume_id'] == v.id}
        if len(attachments) > 1:
            log.debug(attachments)
            for a, h in attachments.items():
                if h != server.compute_host:
                    log.warn(f"Found stale attachment {a} on host {h} for volume {v.id}")
                    #conn.compute.delete_volume_attachment(a, server.id)

    log.info(f"Fix-attachments finished")

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Remove stale duplicated volume attachments to an instance")
    parser.add_argument("instance", help="Instance name or UUID")
    parser.add_argument("-v", "--verbose", help="Increase output verbosity", action="count", default=0)
    opts = parser.parse_args()

    logging.basicConfig(format="%(asctime)s %(name)s %(levelname)s: %(message)s")

    verbosity = {
        0: logging.WARN,
        1: logging.INFO,
        2: logging.DEBUG
    }.get(opts.verbose, logging.DEBUG)

    logging.getLogger('fix_attachments').setLevel(verbosity)

    fix_attachments(opts.instance)

# vim:et:sts=4:sw=4
