# HP Victus Linux Charge Limit

Experimental Linux battery charge limiter for selected HP laptops using HP WMI charge behaviour.

**Tested successfully on one HP Victus system with board ID 8DCD.** Other 8DCD systems may have different BIOS/EC firmware. A matching board ID is not a compatibility guarantee.

## Features

- Software-controlled 75%–80% charging window with hysteresis.
- Automatic charging restored when AC is disconnected.
- Approximately 30-second systemd checks.
- Read-only compatibility report, DKMS packaging, explicit installation confirmation and retained rollback backup.
- Complete driver source and a patch against a pinned TUXOV revision.

## How it works

A custom `hp-wmi` driver exposes `/sys/class/power_supply/BAT0/charge_behaviour`. The controller selects `auto` or `inhibit-charge` through that interface. The adapted driver uses HP WMI command `0x2B` (GBCO read / SBCO write).

This is a **software-controlled 75%–80% charging window using HP firmware charge behaviour**, not a real firmware numeric charge threshold. It is not equivalent to `charge_control_end_threshold=80`. Linux and the timer must be running for the window to be enforced. See [How it works](docs/HOW-IT-WORKS.md).

## Tested hardware

| Component | Tested configuration |
| --- | --- |
| Laptop | HP Victus 15 |
| Board | HP / 8DCD / 50.11 |
| BIOS | F.07, reported date `03/04/2026` |
| Distribution | CachyOS / Arch Linux |
| Kernel | `7.2.9-1-cachyos` |
| Compiler | Clang 23.1.1 |
| Battery / adapter | BAT0 / ADP1 |

The original tested DKMS package was `hp-wmi-fan-and-backlight-control/0.0.4`. This project uses its own package identity, `hp-victus-charge-limit/0.1.0`, and does not remove the original package. See [test evidence](docs/TESTED-HARDWARE.md).

## Requirements

Bash, systemd, DKMS, make, kmod (`modinfo`, `depmod`), coreutils, grep, sed, util-linux (`flock`), and prepared headers matching the target kernel. Git is needed to clone. Python 3 is needed only for development tests. `mokutil` is optional for Secure Boot diagnostics.

Install your distribution's build tools and the headers for the **exact kernel you run**. On CachyOS that means the matching CachyOS headers, not an unrelated Arch kernel's headers. The build helper reads each target kernel's configuration: Clang kernels require Clang, LLD and the LLVM tools; GCC kernels require GCC. Match the compiler version used by the kernel where possible. Dependencies are checked, not automatically installed. Other kernel versions and distributions have not been validated; older kernels may lack required battery-extension APIs.

Secure Boot requires a trusted module-signing setup. Neither script disables it or enrolls keys automatically.

## Compatibility check

```bash
git clone https://github.com/rizhamhd/hp-victus-linux-charge-limit.git
cd hp-victus-linux-charge-limit
./check-support.sh
```

This script only reads diagnostic information. It does not write to firmware or change charge behaviour. Review output before sharing it publicly.

## Installation

**Already using the working experimental setup? Keep it.** Packaging this project does not require reinstalling. The installer deliberately refuses existing controllers, units, custom HP WMI DKMS packages and source trees. It will not migrate them automatically. See [rollback and existing installations](docs/ROLLBACK.md).

For a clean, supported system, review the scripts and run:

```bash
sudo ./install.sh
```

Type `INSTALL` at the prompt. It backs up the selected distribution module under `/var/lib/hp-victus-charge-limit/backups/`, builds and installs through DKMS, installs the controller and units, and reloads systemd. It never unloads or reloads a driver. The timer remains disabled until activation.

Reboot **manually, when convenient**, after checking DKMS build/signing results. If your initramfs embeds `hp-wmi`, refresh it using your distribution's normal procedure before rebooting. Then run:

```bash
sudo ./install.sh --activate
```

Type `INSTALL` again to authorize automatic charge-mode changes. Activation checks the interface, installed-file checksums and loaded module identity, then enables and starts the timer. This two-stage process avoids unloading an in-use driver. No force-discharge operation is performed. The scripts are conservative initial-install tools, not an automatic upgrade manager.

## Usage

Once activated, the timer runs automatically. Inspect it with:

```bash
systemctl status hp-battery-limit.timer
journalctl -u hp-battery-limit.service -b
```

The controller targets BAT0 and ADP1, matching the tested machine. Other device names require code review and additional testing. Avoid other tools that write charge behaviour concurrently.

To pause automation, explicitly stop the timer:

```bash
sudo systemctl stop hp-battery-limit.timer
sudo systemctl stop hp-battery-limit.service
```

Stopping it preserves the last firmware policy; it does not restore `auto`. If you want normal charging after stopping it:

```bash
printf 'auto\n' | sudo tee /sys/class/power_supply/BAT0/charge_behaviour
```

## Verification

```bash
printf 'Battery: '; cat /sys/class/power_supply/BAT0/capacity
printf 'Status:  '; cat /sys/class/power_supply/BAT0/status
printf 'Mode:    '; cat /sys/class/power_supply/BAT0/charge_behaviour
```

Illustrative output at the upper boundary:

```text
Battery: 80
Status:  Not charging
Mode:    auto [inhibit-charge] force-discharge
```

`[]` indicates the active behaviour. `force-discharge` appears among the driver's supported behaviours; the project's automation never selects it. The actual successful initial test was at **99%**, with `Not charging`, `[inhibit-charge]` and AC online `1`. Inhibiting charge at 99% does not deliberately bring the battery down to 80%.

## 75/80 hysteresis explanation

| Condition | Action |
| --- | --- |
| AC disconnected | Select `auto` |
| AC connected, battery ≥80% | Select `inhibit-charge` |
| AC connected, battery ≤75% | Select `auto` |
| AC connected, battery 76–79% | Preserve the current mode |
| Missing or invalid readings | Report an error; do not write |

Separate start/stop boundaries prevent rapid switching. Polling, battery gauge rounding, suspend and load can cause overshoot or a percentage outside the window. A battery initially above 80% can remain there for a long time. No intentional discharge is used.

## Gaming while plugged in

On the tested machine, while inhibited and connected to AC, the battery reported `Not charging` and AC remained online. This does **not** prove a hardware electrical bypass. Under gaming load the adapter, firmware and platform power policy can affect battery use; the project does not promise zero battery discharge, reduced temperatures or improved performance.

## Kernel updates / DKMS

DKMS autoinstall is enabled. The build helper detects Clang versus GCC separately for each target kernel. Keep matching headers and compiler tools installed, and inspect `dkms status` after kernel updates before rebooting. A successful build does not prove firmware compatibility. Source API changes can break builds; keep a known-working boot option. Modules embedded in an initramfs may require rebuilding it through your distribution's tooling.

## Uninstallation

```bash
sudo ./uninstall.sh
```

Type `UNINSTALL`. The script requires its own installation record, stops the timer/service, restores `auto` if the interface exists, removes its files and **only** `hp-victus-charge-limit/0.1.0`, reloads systemd and runs depmod. Modified files are preserved for review. DKMS normally restores saved original modules; the independent backup remains available. Reboot manually to stop using the still-loaded custom driver. See [rollback](docs/ROLLBACK.md).

## Troubleshooting

Start with `./check-support.sh`, `dkms status` and the service journal. Missing `charge_behaviour`, compiler failures, signing errors and competing drivers are covered in [Troubleshooting](docs/TROUBLESHOOTING.md).

## Safety warning

This is experimental firmware-facing software without a compatibility guarantee or warranty. Review changes before installation and retain a recovery boot option. The provided automation never uses force-discharge, changes BIOS settings, disables Secure Boot or directly accesses EC registers. Installation and uninstallation intentionally modify system files; activation and uninstallation intentionally change charge policy. Do not run them merely to inspect support.

## Known limitations

- One tested system; matching 8DCD boards can have different firmware.
- The exact driver source was hardware-tested in the experimental setup. The new installer/uninstaller have not been exercised on the maintainer's live installation, to preserve it.
- The driver is a full replacement and includes inherited fan, keyboard and platform functionality. This is not a battery-only module.
- The sysfs mode is cached by this driver after initialization and successful writes; it is not a fresh GBCO firmware read on every access.
- No hard 80% cap, powered-off enforcement, immediate unplug reaction, electrical-bypass guarantee or supported force-discharge workflow.
- The interval is approximate (30 seconds, with 5 seconds of timer accuracy); suspend delays execution.
- No automatic migration from another hp-wmi package, kernel compatibility guarantee, or automatic initramfs/signing configuration.

## Credits

- **Upstream Linux developers:** the original hp-wmi driver and the battery charge behaviour work on which this adaptation is based. Existing source copyright and author notices are retained. Credit to Shang En Sim for the [upstream Spectre charge_behaviour work](https://lore.kernel.org/r/20261001031012.48473-3-sim@shangen.org/) and the Linux developers who reviewed and contributed to it; this experimental enablement is not a claim of upstream acceptance for 8DCD.
- **[TUXOV](https://github.com/TUXOV/hp-wmi-fan-and-backlight-control):** the base fan/backlight driver, pinned at `2816846199328da03f88dd8f3d1b852e5b999058`.
- **Rio Abishek ([rizhamhd](https://github.com/rizhamhd)):** experimental 8DCD enablement/testing, 75/80 userspace automation and project maintenance. The maintainer did not write the entire hp-wmi driver.

See [source provenance](docs/SOURCE-PROVENANCE.md) for the precise source/patch relationship.

## License

GPL-2.0-or-later, consistent with the driver's existing SPDX identifier. The upstream GPL version 2 license text is preserved in [LICENSE](LICENSE); new scripts use the same SPDX identifier. Original copyright notices remain intact.
