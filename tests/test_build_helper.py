#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Check per-kernel compiler choice with fake tools; no kernel builds or writes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / 'driver/build-module.sh'
BASH = shutil.which('bash')


class BuildHelperTests(unittest.TestCase):
    def check_config(self, config, tools):
        with tempfile.TemporaryDirectory(prefix='hp-compiler-test-') as tmp:
            root = Path(tmp)
            (root / 'include/config').mkdir(parents=True)
            (root / 'include/config/auto.conf').write_text(config)
            bin_dir = root / 'bin'
            bin_dir.mkdir()
            (bin_dir / 'grep').symlink_to(shutil.which('grep'))
            for tool in tools:
                path = bin_dir / tool
                path.write_text('#!/bin/sh\nexit 0\n')
                path.chmod(0o755)
            return subprocess.run([BASH, str(HELPER), str(root), str(root), '--check'],
                                  env=dict(os.environ, PATH=str(bin_dir)),
                                  capture_output=True, text=True, check=False)

    def test_gcc_kernel(self):
        result = self.check_config('CONFIG_CC_IS_GCC=y\n', ['gcc'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('CC=gcc', result.stdout)
        self.assertNotIn('LLVM=1', result.stdout)

    def test_clang_kernel(self):
        result = self.check_config('CONFIG_CC_IS_CLANG=y\n', [
            'clang', 'ld.lld', 'llvm-ar', 'llvm-nm', 'llvm-objcopy',
            'llvm-objdump', 'llvm-readelf', 'llvm-strip'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('LLVM=1 CC=clang', result.stdout)

    def test_unknown_compiler_refused(self):
        result = self.check_config('', ['gcc', 'clang'])
        self.assertNotEqual(result.returncode, 0)

    def test_missing_toolchain_refused(self):
        for config in ('CONFIG_CC_IS_GCC=y\n', 'CONFIG_CC_IS_CLANG=y\n'):
            self.assertNotEqual(self.check_config(config, []).returncode, 0)


if __name__ == '__main__':
    unittest.main()
