#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
PATH=/usr/sbin:/usr/bin:/sbin:/bin
export PATH
name=hp-victus-charge-limit
version=0.1.0
source_dir=/usr/src/$name-$version
state=/var/lib/$name/install
fail() { echo "Error: $*" >&2; exit 1; }
[[ $# == 0 ]] || fail 'Usage: sudo ./uninstall.sh'
[[ $EUID == 0 ]] || fail 'Run with sudo.'
[[ -d $state && ! -L $state ]] || fail 'No project installation state; nothing will be removed.'
for tool in dkms systemctl depmod sha256sum flock grep cat rm rmdir mv date; do
    command -v "$tool" >/dev/null || fail "Missing tool: $tool"
done
echo 'This stops the project timer, restores auto charging, and removes only this project version.'
echo 'The loaded driver remains in memory until you choose to reboot. Backups are retained.'
printf 'Type UNINSTALL to continue: '
read -r answer
[[ $answer == UNINSTALL ]] || fail 'Cancelled.'
exec 9>/run/lock/hp-victus-charge-limit.lock
flock -n 9 || fail 'Another installation/uninstallation is running.'
# Refuse to remove files that have since been modified or replaced.
if [[ -f $state/files.sha256 ]]; then
    while read -r hash path; do
        case "$path" in
            "$source_dir/hp-wmi.c"|"$source_dir/Makefile"|"$source_dir/dkms.conf"|"$source_dir/build-module.sh"|/usr/local/bin/hp-battery-limit|/etc/systemd/system/hp-battery-limit.service|/etc/systemd/system/hp-battery-limit.timer) ;;
            *) fail 'Unexpected path in installation manifest.' ;;
        esac
        if [[ -e $path || -L $path ]]; then
            [[ ! -L $path ]] || fail "Replaced path preserved: $path"
            [[ $(sha256sum "$path") == "$hash  $path" ]] || fail "Modified file preserved: $path. Review recovery documentation."
        fi
    done < "$state/files.sha256"
fi
if [[ -f /etc/systemd/system/hp-battery-limit.timer ]] && grep -q ' /etc/systemd/system/hp-battery-limit.timer$' "$state/files.sha256"; then
    systemctl disable --now hp-battery-limit.timer
    systemctl stop hp-battery-limit.service
fi
# Restore normal policy only after the automation has stopped.
if [[ -e /sys/class/power_supply/BAT0/charge_behaviour ]]; then
    printf 'auto\n' > /sys/class/power_supply/BAT0/charge_behaviour
fi
status=$(dkms status -m "$name" -v "$version")
if [[ -n $status ]]; then
    dkms remove -m "$name" -v "$version" --all
fi
if [[ -f $state/files.sha256 ]]; then
    while read -r _ path; do
        [[ ! -e $path ]] || rm -- "$path"
    done < "$state/files.sha256"
fi
if [[ -d $source_dir ]]; then
    rmdir -- "$source_dir" || fail 'Unexpected files remain in project source directory; preserved for review.'
fi
systemctl daemon-reload
depmod -a
echo 'DKMS normally restores the original module it saved during installation.'
backup=$(cat "$state/backup-path")
if [[ -r $backup/module-path ]]; then
    previous=$(cat "$backup/module-path")
    if [[ ! -f $previous ]]; then
        echo "Previous module is missing: $previous" >&2
        echo "Reinstall the matching distribution kernel package before reboot; retained backup: $backup" >&2
        exit 1
    fi
fi
# Keep the recovery record and backup; mark this installation as removed.
mv -- "$state" "${state}.removed-$(date -u +%Y%m%dT%H%M%SZ)-$$"
echo "Removed project installation. Recovery backup retained: $backup"
echo 'Reboot manually to use the restored distribution driver. Refresh your initramfs first if it embeds hp-wmi.'
