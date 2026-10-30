#!/bin/bash -e
#
# Stage60/06: Boot-time optimisation for Crankshaft head units.
#
# Targets the "power on -> UI on screen" path on low-end boards (Pi Zero 2 W,
# Pi 3) driving an HDMI panel. Every change is controlled by a build variable
# (see pi-gen-stages/config-template) so other hardware can opt out.
#
#   CRANKSHAFT_FAST_BOOT=1            master switch for this stage (default 1)
#   CRANKSHAFT_DISABLE_AUTODETECT=1   skip firmware camera/DSI probing (default 1)
#   CRANKSHAFT_QUIET_BOOT=1           silent kernel console, no logo/cursor (default 1)
#   CRANKSHAFT_HDMI_MODE=""           e.g. "800x480@60" to force the HDMI mode
#                                     for panels with a missing/bad EDID or that
#                                     power up after the Pi (default: use EDID)
#   CRANKSHAFT_DISABLE_TTY1_GETTY=1   no login prompt behind the UI (default 1)

FAST_BOOT="${CRANKSHAFT_FAST_BOOT:-1}"
DISABLE_AUTODETECT="${CRANKSHAFT_DISABLE_AUTODETECT:-1}"
QUIET_BOOT="${CRANKSHAFT_QUIET_BOOT:-1}"
HDMI_MODE="${CRANKSHAFT_HDMI_MODE:-}"
DISABLE_TTY1_GETTY="${CRANKSHAFT_DISABLE_TTY1_GETTY:-1}"

if [ "${FAST_BOOT}" != "1" ]; then
    echo "Stage60/06: CRANKSHAFT_FAST_BOOT != 1, skipping boot optimisation"
    exit 0
fi

# Bookworm/Trixie images mount the FAT boot partition at /boot/firmware.
BOOT_DIR="${ROOTFS_DIR}/boot/firmware"
if [ ! -f "${BOOT_DIR}/config.txt" ]; then
    BOOT_DIR="${ROOTFS_DIR}/boot"
fi
CONFIG_TXT="${BOOT_DIR}/config.txt"
CMDLINE_TXT="${BOOT_DIR}/cmdline.txt"

if [ ! -f "${CONFIG_TXT}" ] || [ ! -f "${CMDLINE_TXT}" ]; then
    echo "Stage60/06: config.txt/cmdline.txt not found under ${BOOT_DIR}" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# config.txt (firmware stage)
# ---------------------------------------------------------------------------
MARKER_BEGIN="# >>> crankshaft boot optimisation >>>"
MARKER_END="# <<< crankshaft boot optimisation <<<"

# Idempotent: drop any previous block before writing a fresh one.
sed -i "/^${MARKER_BEGIN}\$/,/^${MARKER_END}\$/d" "${CONFIG_TXT}"

if [ "${DISABLE_AUTODETECT}" = "1" ]; then
    # Turn off the stock auto-detect lines so our values are not overridden.
    sed -i -E 's/^(camera_auto_detect|display_auto_detect)=1/#&  # disabled by crankshaft/' "${CONFIG_TXT}"
fi

{
    echo "${MARKER_BEGIN}"
    echo "[all]"
    echo "# No rainbow splash, no artificial pre-kernel delay."
    echo "disable_splash=1"
    echo "boot_delay=0"
    echo "# Run the CPU at full clock for the first 30s so boot is not"
    echo "# limited by the on-demand governor ramping up."
    echo "initial_turbo=30"
    if [ "${DISABLE_AUTODETECT}" = "1" ]; then
        echo "# HDMI-only head unit: skip firmware probing for CSI cameras / DSI panels."
        echo "camera_auto_detect=0"
        echo "display_auto_detect=0"
    fi
    echo "${MARKER_END}"
} >> "${CONFIG_TXT}"

echo "Stage60/06: config.txt updated"

# ---------------------------------------------------------------------------
# cmdline.txt (kernel) - single line, append only tokens not already present
# ---------------------------------------------------------------------------
append_cmdline_token() {
    local token="$1"
    local key="${token%%=*}"
    # Replace an existing key=value, otherwise append.
    if grep -qE "(^| )${key}(=| |\$)" "${CMDLINE_TXT}"; then
        sed -i -E "s#(^| )${key}(=[^ ]*)?( |\$)#\\1${token}\\3#" "${CMDLINE_TXT}"
    else
        sed -i -E "1 s#\$# ${token}#" "${CMDLINE_TXT}"
    fi
}

if [ "${QUIET_BOOT}" = "1" ]; then
    append_cmdline_token "quiet"
    append_cmdline_token "loglevel=3"
    append_cmdline_token "logo.nologo"
    append_cmdline_token "vt.global_cursor_default=0"
fi

if [ -n "${HDMI_MODE}" ]; then
    # Trailing "D" forces the connector on even if hotplug/EDID is not seen in
    # time (car panels often power up after the Pi), so the UI never falls
    # back to VNC mode.
    append_cmdline_token "video=HDMI-A-1:${HDMI_MODE}D"
fi

# Keep it a single line with no trailing whitespace.
sed -i -E 's/[[:space:]]+$//' "${CMDLINE_TXT}"
echo "Stage60/06: cmdline.txt is now:"
cat "${CMDLINE_TXT}"

# ---------------------------------------------------------------------------
# systemd units that cost boot time but do nothing useful in a head unit
# ---------------------------------------------------------------------------
on_chroot << EOF
set -e

disable_if_present() {
    for unit in "\$@"; do
        if systemctl list-unit-files "\${unit}" --no-legend 2>/dev/null | grep -q .; then
            systemctl disable "\${unit}" >/dev/null 2>&1 || true
            echo "  disabled \${unit}"
        fi
    done
}

# Nothing in Crankshaft orders on network-online.target; these only stall boot.
systemctl mask NetworkManager-wait-online.service systemd-networkd-wait-online.service >/dev/null 2>&1 || true

# Background maintenance that competes with UI start-up for SD-card I/O.
disable_if_present apt-daily.timer apt-daily-upgrade.timer man-db.timer e2scrub_all.timer

# Console/keyboard setup for a TTY nobody sees; modem and hotkey daemons.
disable_if_present keyboard-setup.service console-setup.service \
    ModemManager.service triggerhappy.service triggerhappy.socket

# zram (stage60/01) already provides swap; a file on the SD card is slower
# and is (re)created at boot.
disable_if_present dphys-swapfile.service

if [ "${DISABLE_TTY1_GETTY}" = "1" ]; then
    # The UI owns the HDMI output via KMS; a getty on tty1 only causes a
    # login prompt to flash before/after the UI. SSH and serial still work.
    systemctl disable getty@tty1.service >/dev/null 2>&1 || true
    echo "  disabled getty@tty1.service"
fi
EOF

echo "Stage60/06: Boot optimisation applied"
