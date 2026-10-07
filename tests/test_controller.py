#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Exercise the controller against temporary files; never touch real sysfs."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

CONTROLLER = Path(__file__).resolve().parents[1] / 'scripts/hp-battery-limit'


class ControllerTests(unittest.TestCase):
    def run_case(self, capacity, online, active, expected, success=True):
        with tempfile.TemporaryDirectory(prefix='hp-charge-test-') as temp:
            root = Path(temp)
            (root / 'BAT0').mkdir()
            (root / 'ADP1').mkdir()
            (root / 'BAT0/capacity').write_text(str(capacity) + '\n')
            if online is not None:
                (root / 'ADP1/online').write_text(str(online) + '\n')
            modes = ' '.join(f'[{m}]' if m == active else m
                             for m in ('auto', 'inhibit-charge', 'force-discharge')) + '\n'
            mode_file = root / 'BAT0/charge_behaviour'
            mode_file.write_text(modes)
            before = mode_file.stat().st_mtime_ns
            env = dict(os.environ, HP_POWER_SUPPLY_ROOT=str(root))
            result = subprocess.run(['bash', str(CONTROLLER)], env=env,
                                    capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode == 0, success, result.stderr)
            self.assertEqual(mode_file.read_text(), modes if expected is None else expected + '\n')
            if expected is None:
                self.assertEqual(mode_file.stat().st_mtime_ns, before)

    def test_boundaries_and_high_charge(self):
        for capacity in (80, 81, 99, 100):
            with self.subTest(capacity=capacity):
                self.run_case(capacity, 1, 'auto', 'inhibit-charge')
        for capacity in (0, 1, 74, 75):
            with self.subTest(capacity=capacity):
                self.run_case(capacity, 1, 'inhibit-charge', 'auto')

    def test_deadband_preserves_each_policy(self):
        for capacity in (76, 77, 78, 79):
            for mode in ('auto', 'inhibit-charge', 'force-discharge'):
                with self.subTest(capacity=capacity, mode=mode):
                    self.run_case(capacity, 1, mode, None)

    def test_unplug_restores_auto(self):
        for capacity in (20, 77, 99):
            self.run_case(capacity, 0, 'inhibit-charge', 'auto')

    def test_no_duplicate_writes(self):
        self.run_case(99, 1, 'inhibit-charge', None)
        self.run_case(75, 1, 'auto', None)
        self.run_case(90, 0, 'auto', None)

    def test_bad_inputs_do_not_write(self):
        for capacity in ('', 'oops', '-1', '101', '1000', '1+2'):
            self.run_case(capacity, 1, 'inhibit-charge', None, success=False)
        for online in (None, '', 'unknown', 2):
            self.run_case(99, online, 'auto', None, success=False)


if __name__ == '__main__':
    unittest.main()
