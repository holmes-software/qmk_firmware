# This script flashes the compiled firmware to a Ploopy device.
#
# Perform the following before running this script:
#   1. Configure. Duh. Configs are `keyboards/ploopyco/madromys/keymaps/holmes_software/keymap.c` and
#      `keyboards/ploopyco/madromys/config.h:34`.
#   2. Compile firmware. Run `qmk compile`. Defaults are already set.
#   3. Enter bootloader mode. To put the device in bootloader mode, hold left click and plug the mouse in. It should
#      then appear in `lsblk` results. You will need those results when running this script.
#
# Then run the script to flash!
#
# Several checks are in place to be sure you don't do something dumb:
#   1. The partition for the filesystem the Ploopy's firmware exposes must be provided and exist.
#   2. `ploopyco_madromys_rev1_001_holmes_software.uf2` (the compiled firmware) must exist in same directory as this script.
#   3. The size of the partition must be exactly 134217216 bytes (just because I know that's what it's supposed to be).
#   4. `INDEX.HTM` and `INFO_UF2.TXT` must exist in the mounted file system (again, I just know these are supposed to be
#      there).

#!/usr/bin/env bash
set -euo pipefail

if [[ "$(whoami)" != "root" ]]; then
    echo "Must run as root"
    exit 1
fi

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
UF2_FILE="${SCRIPT_DIR}/ploopyco_madromys_rev1_001_holmes_software.uf2"

read -r -p "Ploopy device partition (e.g. /dev/sdb1): " PARTITION

if [[ -z "${PARTITION}" ]]; then
    echo "No partition provided." >&2
    exit 1
fi

if [[ ! -b "${PARTITION}" ]]; then
    echo "Partition does not exist or is not a block device: ${PARTITION}" >&2
    exit 1
fi

if [[ ! -f "${UF2_FILE}" ]]; then
    echo "UF2 file not found: ${UF2_FILE}" >&2
    exit 1
fi

SIZE_BYTES="$(blockdev --getsize64 "${PARTITION}")"
EXPECTED_SIZE_BYTES=134217216

if [[ "${SIZE_BYTES}" -ne "${EXPECTED_SIZE_BYTES}" ]]; then
    echo "Partition size is not 128M: ${PARTITION} is ${SIZE_BYTES} bytes." >&2
    exit 1
fi

MOUNT_DIR="$(mktemp -d)"
cleanup() {
    if mountpoint -q "${MOUNT_DIR}"; then
        umount "${MOUNT_DIR}"
    fi
    rmdir "${MOUNT_DIR}"
}
trap cleanup EXIT

mount "${PARTITION}" "${MOUNT_DIR}"

if [[ ! -f "${MOUNT_DIR}/INDEX.HTM" ]] || [[ ! -f "${MOUNT_DIR}/INFO_UF2.TXT" ]]; then
    echo "Missing INDEX.HTM and/or INFO_UF2.TXT files in mounted device. Likely not a Ploopy device."
    exit 1
fi

cp "${UF2_FILE}" "${MOUNT_DIR}/"
sync
