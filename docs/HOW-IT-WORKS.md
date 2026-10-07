# How it works

The complete hp-wmi replacement registers a battery power-supply extension when a DMI allowlist matches. This experimental source adds HP board 8DCD; inherited Spectre entries are not a claim of testing by this project. The installer only accepts HP / 8DCD.

HP WMI command `0x2B` provides GBCO read / SBCO write. SBCO receives the requested mode in bits 15:8; GBCO status is interpreted from bits 7:0.

| Write value | Behaviour |
| --- | --- |
| `0x00` | AUTO |
| `0x02` | FORCE_DISCHARGE (driver capability only; never selected by project scripts) |
| `0x05` | INHIBIT_CHARGE |

| Read value | Interpretation |
| --- | --- |
| `0x00`, `0x01` | AUTO |
| `0x02` | FORCE_DISCHARGE |
| `0x04`, `0x05`, `0x06` | INHIBIT_CHARGE |

The driver initializes its cached mode from GBCO and updates the cache after successful SBCO writes. Sysfs reads return that cache, so compare mode with battery status and AC state when diagnosing. Firmware may report `0x02` on battery alone; a report does not establish that the automation requested force-discharge.

Every approximately 30 seconds the controller reads BAT0 capacity, ADP1 online and charge behaviour. Disconnected AC selects auto. On AC, ≥80% selects inhibit-charge and ≤75% selects auto; 76–79% leaves the current mode unchanged. It avoids duplicate writes. Invalid or missing inputs fail without changing the policy. Logs go to stdout/stderr and systemd captures them in the journal.

This implements a software-controlled 75%–80% charging window using HP firmware charge behaviour, not `charge_control_end_threshold=80`. It cannot enforce a hard numeric limit or react while Linux is not running. Inhibited firmware policy may persist across reboot; stopping the timer alone does not restore auto.

Inhibit-charge does not establish a hardware electrical bypass. On the tested machine it correlated with `Not charging` and AC online `1`. Adapter limits, load and firmware can still influence battery usage.
