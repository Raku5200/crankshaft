#!/bin/bash -e

echo "Stage60/04: Applying Raspberry Pi OS optimization files"

install -d -m 755 "${ROOTFS_DIR}/etc/sysctl.d"
install -d -m 755 "${ROOTFS_DIR}/etc/systemd/journald.conf.d"
install -d -m 755 "${ROOTFS_DIR}/etc/systemd/coredump.conf.d"
install -d -m 2755 -g systemd-journal "${ROOTFS_DIR}/var/log/journal" 2>/dev/null || install -d -m 2755 "${ROOTFS_DIR}/var/log/journal"

install -m 644 files/etc/sysctl.d/60-crankshaft-rpi.conf "${ROOTFS_DIR}/etc/sysctl.d/"
install -m 644 files/etc/systemd/journald.conf.d/60-crankshaft.conf "${ROOTFS_DIR}/etc/systemd/journald.conf.d/"
install -m 644 files/etc/systemd/coredump.conf.d/60-crankshaft.conf "${ROOTFS_DIR}/etc/systemd/coredump.conf.d/"

echo "Stage60/04: Optimization files staged"
