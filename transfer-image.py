#!/usr/bin/env python3

import logging
import openstack
import sys


def transfer(src_cloud, dst_cloud, src_images, dry_run):
    log = logging.getLogger('copy-image')

    log.info("Starting copy process")

    src = openstack.connect(src_cloud)
    dst = openstack.connect(dst_cloud)

    log.debug("Connected to OpenStack API")

    for img_id in src_images:
        log.debug(f"Looking up image {img_id}")
        src_img = src.get_image(img_id)
        try:
            dst_img = next(dst.image.images(tag=[f'src_id={img_id}']))
            log.debug(f"Image {src_img.name} ({src_img.id}) already exists in destination cloud ({dst_img.id})")
            continue
        except StopIteration: pass

        log.info(f"Uploading image {src_img.name} ({src_img.id})")
        if dry_run:
            continue
        dst_img = dst.image.create_image(
            name=src_img.name,
            container_format=src_img.container_format,
            disk_format=src_img.disk_format,
            #visibility=src_img.visibility,
            #metadata=src_img.metadata,
            min_ram=src_img.min_ram,
            min_disk=src_img.min_disk,
            #virtual_size=src_img.virtual_size,
            #tags=list(set(src_img.tags+[f'src_id={img_id}'])),
            #md5=src_img.get('checksum'),
            validate_checksum=False,
            data=src.image.download_image(src_img, stream=True).raw
        )
        log.info(f"Upload completed: {dst_img}")

    log.info("Done")


if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description="Transfer Glance images between two OpenStack clouds")
    parser.add_argument("-v", "--verbose", help="Increase output verbosity", action="count", default=0)
    parser.add_argument("-n", "--dry-run", help="Do not really upload", action="store_true")
    parser.add_argument("src_cloud", type=str, help="Source cloud name", nargs=1)
    parser.add_argument("dst_cloud", type=str, help="Destination cloud name", nargs=1)
    parser.add_argument("images", type=str, help="Images to transfer", nargs='+')
    opts = parser.parse_args()

    logging.basicConfig(format="%(asctime)s %(name)s %(levelname)s: %(message)s")

    if opts.verbose > 1:
        verbosity = logging.DEBUG
    else:
        verbosity = {
            0: logging.INFO,
            1: logging.DEBUG
        }.get(opts.verbose)

    logging.getLogger('copy-image').setLevel(verbosity)

    transfer(opts.src_cloud[0], opts.dst_cloud[0], opts.images, opts.dry_run)

# vim:et:sts=4:sw=4
