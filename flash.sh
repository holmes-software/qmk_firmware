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
