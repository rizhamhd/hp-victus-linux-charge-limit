# Troubleshooting

Start with read-only checks:

```bash
./check-support.sh
dkms status
systemctl status hp-battery-limit.timer
journalctl -u hp-battery-limit.service -b
modinfo -n hp_wmi
journalctl -k -b
```

Review logs before sharing them; they may include information unrelated to this project.

## Missing charge_behaviour

A matching board is not sufficient. Check that the replacement driver built for the running kernel, that its signed module was accepted, and that the new module actually loaded after your planned reboot. The driver quietly skips the extension if GBCO fails or returns an unsupported status. Do not bypass the DMI guard or probe raw EC registers. Activation deliberately refuses a missing interface.

## Existing experimental installation

The installer refuses existing controller files, unit definitions, HP WMI sources or DKMS packages. This is intentional protection, including the original 0.0.4 setup. This project does not include an automatic migration procedure. Keep the working implementation while reviewing a separately planned migration and recovery path.

## Compiler or kernel API errors

Install headers matching the target kernel. The helper reads `CONFIG_CC_IS_CLANG` or `CONFIG_CC_IS_GCC` from its prepared headers. Clang requires LLVM tools and LLD; GCC builds use GCC. Check the DKMS `make.log` under `/var/lib/dkms/hp-victus-charge-limit/0.1.0/`. Compiler-version mismatch or kernel API changes may require additional porting; only the documented kernel has been tested. A failed install leaves a recovery record for `uninstall.sh`.

## Secure Boot / rejected module

Use `mokutil --sb-state` if installed, and inspect the kernel log for signature rejection. Follow your distribution's DKMS module-signing and key-enrollment procedure. Do not disable Secure Boot as a workaround. The project does not enroll keys or weaken security. Its checker reports unknown when detection is unavailable.

## Wrong module after reboot

Check `modinfo -n hp_wmi` and `/sys/module/hp_wmi/srcversion`. Another DKMS package or a copy in the initramfs may win. The activation guard compares installed and loaded source versions and expects a DKMS module path. Review distribution-specific module selection and initramfs rebuilding rather than unloading hp_wmi live. Nonstandard DKMS layouts may require manual review.

## Battery stays above 80%, or drops under load

This is expected if installation began above 80%; no intentional discharge occurs. High load can also draw on the battery depending on platform power policy. Check AC online, actual battery status, timer state and journal. The displayed mode is cached. Timer delays and gauge rounding mean the window is approximate.

## Missing adapter or conflicting automation

The controller expects BAT0 and ADP1. Missing/invalid readings make it fail without writing. Review other battery tools and services before changing anything. Do not run multiple policy writers. At 76–79% the existing mode is deliberately preserved.
