#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
name=hp-victus-charge-limit
version=0.1.0
source_dir=/usr/src/$name-$version
state=/var/lib/$name/install
kernel=$(uname -r)
fail() { echo "Error: $*" >&2; exit 1; }
usage() { echo 'Usage: sudo ./install.sh [--activate]'; }
[[ $# == 0 || ( $# == 1 && $1 == --activate ) ]] || { usage; exit 1; }
[[ $EUID == 0 ]] || fail 'Run with sudo after reading README.md.'
[[ $(cat /sys/class/dmi/id/board_vendor) == HP && $(cat /sys/class/dmi/id/board_name) == 8DCD ]] ||
    fail 'Only HP board 8DCD is allowlisted; no override is provided.'
for tool in dkms make modinfo depmod systemctl install sha256sum flock cp date grep cat uname dirname touch; do
    command -v "$tool" >/dev/null || fail "Required tool missing: $tool"
done
[[ -d /run/systemd/system ]] || fail 'A running systemd system is required.'
cat <<'WARNING'
EXPERIMENTAL: Tested successfully on one HP Victus system with board ID 8DCD.
Other 8DCD systems may have different BIOS/EC firmware.
Installation replaces the on-disk hp-wmi driver using DKMS and saves a backup.
Activation starts a timer that writes auto/inhibit-charge to BAT0 firmware policy.
No module is unloaded or loaded here. Reboot is always your decision.
WARNING
printf 'Type INSTALL to continue: '
read -r answer
[[ $answer == INSTALL ]] || fail 'Cancelled.'
exec 9>/run/lock/hp-victus-charge-limit.lock
flock -n 9 || fail 'Another installation/uninstallation is running.'
if [[ ${1:-} == --activate ]]; then
    [[ -f $state/ready ]] || fail 'Complete the install phase first.'
    sha256sum --check --status "$state/files.sha256" || fail 'Installed files changed; inspect before activation.'
    [[ -r /sys/class/power_supply/BAT0/charge_behaviour ]] ||
        fail 'charge_behaviour absent: check DKMS, Secure Boot and boot logs; see docs/TROUBLESHOOTING.md.'
    installed=$(dkms status -m "$name" -v "$version" -k "$kernel")
    [[ $installed == *": installed"* ]] || fail 'This project DKMS version is not installed for the running kernel.'
    selected=$(modinfo -n hp_wmi)
    [[ $selected == */updates/dkms/hp-wmi.ko* ]] || fail 'The DKMS driver is not selected by modinfo.'
    expected=$(modinfo -F srcversion hp_wmi)
    loaded=$(cat /sys/module/hp_wmi/srcversion 2>/dev/null || true)
    [[ -n $expected && $expected == "$loaded" ]] || fail 'Loaded driver differs from installed driver; reboot when convenient, then retry.'
    mode=$(cat /sys/class/power_supply/BAT0/charge_behaviour)
    [[ $mode == *auto* && $mode == *inhibit-charge* ]] || fail 'Required charge behaviours missing.'
    [[ -r /sys/class/power_supply/ADP1/online ]] || fail 'Expected ADP1 adapter missing.'
    systemctl daemon-reload
    systemctl enable --now hp-battery-limit.timer
    "$project/check-support.sh"
    echo 'Timer activated. Inspect systemctl status hp-battery-limit.timer and the service journal.'
    exit 0
fi
[[ ! -e $state && ! -e $source_dir ]] || fail 'An installation or recovery state already exists; consult docs/ROLLBACK.md.'
for target in /usr/local/bin/hp-battery-limit /etc/systemd/system/hp-battery-limit.{service,timer}; do
    [[ ! -e $target && ! -L $target ]] || fail "Existing file preserved: $target. Automatic migration is deliberately refused."
done
for unit in hp-battery-limit.service hp-battery-limit.timer; do
    fragment=$(systemctl show "$unit" -p FragmentPath --value)
    [[ -z $fragment ]] || fail "Existing unit preserved: $fragment"
done
status=$(dkms status) || fail 'Cannot inspect DKMS state.'
if grep -Eqi 'hp[-_]wmi|hp-victus-charge-limit' <<< "$status"; then
    fail 'An existing HP WMI DKMS installation was found. Automatic migration is deliberately refused.'
fi
shopt -s nullglob
existing_sources=(/usr/src/hp-wmi*)
(( ${#existing_sources[@]} == 0 )) || fail 'Existing hp-wmi source preserved; automatic migration is refused.'
"$project/driver/build-module.sh" "/lib/modules/$kernel/build" "$source_dir" --check
previous=$(modinfo -n hp_wmi) || fail 'Cannot locate the previous driver for backup.'
[[ -f $previous && $previous == /lib/modules/*/kernel/* || -f $previous && $previous == /usr/lib/modules/*/kernel/* ]] ||
    fail 'Previous driver is not a regular distribution module; manual migration is required.'
if command -v mokutil >/dev/null; then mokutil --sb-state || true; fi
echo 'If Secure Boot is enabled, arrange trusted DKMS module signing before reboot. Security settings are not changed.'
backup=/var/lib/$name/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$
install -d -m 700 "$backup" "$state"
printf '%s\n' "$backup" > "$state/backup-path"
printf '%s\n' "$previous" > "$backup/module-path"
printf '%s\n' "$kernel" > "$backup/kernel"
printf '%s\n' "$status" > "$backup/dkms-status"
cp -p -- "$previous" "$backup/"
# Only new, project-owned paths are written below. State survives errors for recovery.
trap 'echo "Install incomplete. Recovery state: $state; run sudo ./uninstall.sh after reviewing docs/ROLLBACK.md." >&2' ERR
install -d -m 755 "$source_dir"
: > "$state/files.sha256"
for file in hp-wmi.c Makefile dkms.conf build-module.sh; do
    install -m 644 "$project/driver/$file" "$source_dir/$file"
    sha256sum "$source_dir/$file" >> "$state/files.sha256"
done
dkms add -m "$name" -v "$version"
dkms build -m "$name" -v "$version" -k "$kernel"
dkms install -m "$name" -v "$version" -k "$kernel"
depmod -a "$kernel"
install -m 755 "$project/scripts/hp-battery-limit" /usr/local/bin/hp-battery-limit
sha256sum /usr/local/bin/hp-battery-limit >> "$state/files.sha256"
for unit in hp-battery-limit.service hp-battery-limit.timer; do
    install -m 644 "$project/systemd/$unit" "/etc/systemd/system/$unit"
    sha256sum "/etc/systemd/system/$unit" >> "$state/files.sha256"
done
systemctl daemon-reload
touch "$state/ready"
"$project/check-support.sh"
cat <<'NEXT'
Installed on disk; timer is not yet enabled. The loaded driver has not changed.
Reboot manually when convenient, then run: sudo ./install.sh --activate
Activation verifies the interface and loaded driver before enabling the timer.
If signing prevents loading, consult docs/TROUBLESHOOTING.md; do not disable Secure Boot.
NEXT
