#!/bin/bash -e

echo "Stage60/02: Preparing OpenCarDev package installation"

# Locally built packages (e.g. our crankshaft-ui-slim fork, dropped here by CI)
# are staged into the rootfs and installed by 03-run-chroot.sh, after the
# stock packages from 02-packages, so they replace the apt.opencardev.org builds.
LOCAL_DEB_DIR="files/local-debs"
if compgen -G "${LOCAL_DEB_DIR}/*.deb" > /dev/null; then
    install -d -m 755 "${ROOTFS_DIR}/tmp/crankshaft-local-debs"
    install -m 644 "${LOCAL_DEB_DIR}"/*.deb "${ROOTFS_DIR}/tmp/crankshaft-local-debs/"
    echo "Stage60/02: Staged local packages:"
    ls -1 "${ROOTFS_DIR}/tmp/crankshaft-local-debs"
else
    echo "Stage60/02: No local packages in ${LOCAL_DEB_DIR}; using repository packages only"
fi
