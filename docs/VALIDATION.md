# Packaging validation

Completed without installing, activating or removing the project on the live test machine:

- Bash syntax checks on installer, uninstaller, checker, controller and build helper.
- ShellCheck 0.11.0 on all five shell scripts.
- Isolated controller tests: thresholds, deadband, unplug, duplicate writes and invalid/missing readings.
- Fake-toolchain tests: per-kernel Clang/GCC selection, unknown compiler rejection and missing tools.
- Actual module compilation against `7.2.9-1-cachyos` headers using Clang/LLVM in a temporary directory. The output module was neither loaded nor included in Git.
- `systemd-analyze verify` on the two unit files.
- Applying the patch to the pinned base reproduces bundled driver source byte-for-byte.
- Original working source, DKMS configuration, controller and unit file checksums unchanged.
- Staged diff/status, text-only file inventory and common secret-pattern review.

Repeat checks from the repository root:

```bash
bash -n install.sh
bash -n uninstall.sh
bash -n check-support.sh
bash -n scripts/hp-battery-limit
bash -n driver/build-module.sh
shellcheck install.sh uninstall.sh check-support.sh scripts/hp-battery-limit driver/build-module.sh
python3 -m unittest discover -s tests -v
systemd-analyze verify systemd/hp-battery-limit.service systemd/hp-battery-limit.timer
git diff --check
```

Unit verification on a development machine may report that the absolute ExecStart target is not installed. Do not install the controller just to suppress that report.

These checks do not establish full installation/rollback, Secure Boot enrollment, new-kernel compatibility or another machine's firmware support. Those require a separate test setup and recovery plan. No packaging check uses force-discharge or writes real battery sysfs.
