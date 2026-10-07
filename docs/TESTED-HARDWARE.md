# Tested hardware

Tested successfully on one HP Victus system with board ID 8DCD.

- Laptop: HP Victus 15
- Board vendor/name/version: HP / 8DCD / 50.11
- BIOS: F.07; DMI date exactly `03/04/2026`
- OS: CachyOS / Arch Linux
- Kernel: `7.2.9-1-cachyos`
- Compiler used: Clang 23.1.1
- Battery/adapter: BAT0 / ADP1
- Original working DKMS identity: `hp-wmi-fan-and-backlight-control/0.0.4`

Observed successful experiment, also confirmed by read-only inspection during packaging:

```text
Battery: 99
Status:  Not charging
Mode:    auto [inhibit-charge] force-discharge
AC online: 1
```

The earlier successful read/write experiment demonstrates GBCO read and SBCO write on this tested machine. Packaging did not repeat writes or test force-discharge. Other 8DCD systems may have different BIOS/EC firmware. The 80% output in the README is illustrative, not a claim that the packaging session performed a full charge cycle.

The new packaging has local syntax, isolated controller and build checks; installation, reboot activation and rollback require separate manual validation on a suitable test setup. Do not replace a working installation merely to test packaging.
