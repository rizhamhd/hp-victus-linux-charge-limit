# Rollback and existing installations

## Preserve an existing working experiment

Do not run installation or uninstallation merely to package or inspect this repository. The original `hp-wmi-fan-and-backlight-control/0.0.4` setup is a separate installation. These scripts neither adopt it nor delete it. Any existing privately maintained recovery backup remains outside this repository and outside these scripts' control.

The installer rejects an existing controller, systemd unit, custom HP WMI DKMS installation or hp-wmi source tree. Migrating those requires a separately reviewed plan with their exact versions, enabled units and recovery files. There is no override flag.

## Remove this project's installation

Run `sudo ./uninstall.sh` from this repository and confirm `UNINSTALL`. It requires `/var/lib/hp-victus-charge-limit/install`, stops the owned timer and service, restores BAT0 to auto if available, removes only the recorded files and `hp-victus-charge-limit/0.1.0`, reloads systemd, and runs depmod. If files were changed, it refuses to delete them; review the checksum manifest and restore the expected project files only when you understand those changes.

DKMS normally saves/restores the displaced original module. Installation independently saves the selected distribution module, original path, kernel version and DKMS status under `/var/lib/hp-victus-charge-limit/backups/`. Existing custom sources are refused before installation, so no unrelated source tree needs restoration. This independent backup is never removed by the uninstaller and must not be committed.

If the previous distribution module is absent, the script reports it and keeps recovery state. Reinstall the matching distribution kernel package before rebooting. Prefer the package manager's matching, signed driver to manually copying an old backup, especially after a kernel update. Never copy a module built for a different kernel. Review `dkms status` and `modinfo -n hp_wmi` after recovery.

The loaded module is intentionally left alone. Reboot manually to use the restored driver. If hp-wmi is embedded in your initramfs, rebuild it using your distribution's normal tooling before reboot. No script reboots, unloads the module or disables Secure Boot.

## Partial installation

Build/install failures leave installation state and backup for recovery. `uninstall.sh` can remove recorded files from a partial installation. Unexpected or modified files are preserved and reported. Do not delete the recovery record to bypass an error. Review the failing step and DKMS logs first. Recovery records are archived after successful removal.

Fresh installation and rollback tooling has not been validated by changing the maintainer's live working setup. Test those paths separately with a recovery boot option available.
