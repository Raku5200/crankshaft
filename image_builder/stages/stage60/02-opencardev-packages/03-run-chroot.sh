#!/bin/bash -e

# Install locally built packages over the repository versions.
# Runs after 02-packages (pi-gen orders substage steps by their numeric prefix).

LOCAL_DEB_DIR="/tmp/crankshaft-local-debs"

if ! compgen -G "${LOCAL_DEB_DIR}/*.deb" > /dev/null; then
    echo "Stage60/02: No local packages to install"
    exit 0
fi

export DEBIAN_FRONTEND=noninteractive

echo "Stage60/02: Installing local packages over repository versions"
# --allow-downgrades: a fork build may carry a lower version number than the
# repository package it replaces.
apt-get install -y --allow-downgrades "${LOCAL_DEB_DIR}"/*.deb

# Hold them so 'apt upgrade' on the device does not swap them back for the
# stock repository builds.
for deb in "${LOCAL_DEB_DIR}"/*.deb; do
    pkg="$(dpkg-deb -f "${deb}" Package)"
    apt-mark hold "${pkg}"
    echo "  installed and held: ${pkg} $(dpkg-query -W -f='${Version}' "${pkg}")"
done

rm -rf "${LOCAL_DEB_DIR}"
