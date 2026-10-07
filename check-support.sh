#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Read-only: no sysfs writes, module loading, or service changes.
set -uo pipefail
read_value() { if [[ -r $1 ]]; then cat "$1"; else printf 'unavailable\n'; fi; }
for field in board_vendor board_name board_version bios_version bios_date; do
    printf '%s: ' "$field"
    read_value "/sys/class/dmi/id/$field"
done
printf 'Kernel: %s\n' "$(uname -r)"
printf 'Distribution: '
if [[ -r /etc/os-release ]]; then
    sed -n 's/^PRETTY_NAME=//p' /etc/os-release
else
    echo unavailable
fi
if [[ -d /sys/module/hp_wmi ]]; then echo 'hp_wmi loaded: yes'; else echo 'hp_wmi loaded: no'; fi
shopt -s nullglob
for device in /sys/class/power_supply/*; do
    type=$(read_value "$device/type")
    case "$type" in
        Battery)
            printf 'BAT device: %s\n' "${device##*/}"
            for attribute in capacity status charge_behaviour; do
                printf '  %s: ' "$attribute"; read_value "$device/$attribute"
            done
            [[ ! -e $device/charge_behaviour ]] || echo '  charge_behaviour exists: yes'
            ;;
        Mains|USB|USB_C|USB_PD)
            printf 'AC/external device: %s (%s)\n  online: ' "${device##*/}" "$type"
            read_value "$device/online"
            ;;
    esac
done
printf 'Secure Boot: '
if command -v mokutil >/dev/null; then
    mokutil --sb-state 2>&1 || echo 'unknown (query failed)'
else
    echo 'unknown (mokutil unavailable)'
fi
if command -v dkms >/dev/null; then
    echo 'DKMS status:'; dkms status 2>&1 || echo 'unavailable at current permissions'
else
    echo 'DKMS: not installed'
fi
if [[ $(read_value /sys/class/dmi/id/board_vendor) == HP && $(read_value /sys/class/dmi/id/board_name) == 8DCD ]]; then
    echo 'Allowlist: HP / 8DCD; this is NOT a firmware compatibility guarantee.'
else
    echo 'Allowlist: unsupported; installer will refuse this hardware.'
fi
echo 'Tested successfully on one HP Victus system with board ID 8DCD.'
