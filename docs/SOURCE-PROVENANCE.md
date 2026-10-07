# Source provenance

The bundled `driver/hp-wmi.c` is byte-for-byte identical to the working experimental driver inspected during packaging. The experimental checkout and installed DKMS source agreed. No kernel binary, build output, private backup, credentials or host-specific absolute home path is part of the repository.

Base: [TUXOV/hp-wmi-fan-and-backlight-control](https://github.com/TUXOV/hp-wmi-fan-and-backlight-control), commit [`2816846199328da03f88dd8f3d1b852e5b999058`](https://github.com/TUXOV/hp-wmi-fan-and-backlight-control/commit/2816846199328da03f88dd8f3d1b852e5b999058).

`patch/hp-wmi-8dcd-charge-control.patch` is the complete delta from that base driver's `hp-wmi.c`, including adapted charge-behaviour support and the 8DCD entry. It is not just a DMI-only patch, and should not be applied a second time to the bundled source.

To reproduce in a separate disposable directory:

```bash
git clone https://github.com/TUXOV/hp-wmi-fan-and-backlight-control.git upstream-driver
cd upstream-driver
git checkout --detach 2816846199328da03f88dd8f3d1b852e5b999058
git apply ../hp-victus-linux-charge-limit/patch/hp-wmi-8dcd-charge-control.patch
cmp hp-wmi.c ../hp-victus-linux-charge-limit/driver/hp-wmi.c
```

Upstream Linux provides the original hp-wmi driver and the battery charge behaviour work adapted here. Shang En Sim authored the related [Spectre charge_behaviour patch series](https://lore.kernel.org/r/20261001031012.48473-3-sim@shangen.org/), with review and contributions from the upstream community. The local experiment did not record an exact imported upstream charge-control commit, so this project does not invent one or imply that its 8DCD modification was accepted upstream.

TUXOV supplied the fan/backlight base. Rio Abishek (rizhamhd) contributed experimental 8DCD enablement/testing, 75/80 userspace automation and project maintenance. Existing source notices remain. The source's `GPL-2.0-or-later` SPDX declaration and upstream GPL v2 license text are preserved; the new shell tooling uses GPL-2.0-or-later as well.
