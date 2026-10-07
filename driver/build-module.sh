#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail
kernel_dir=${1:?Kernel build directory required}
module_dir=${2:?Module build directory required}
config="$kernel_dir/include/config/auto.conf"
[[ -r $config ]] || { echo "Missing prepared kernel headers: $config" >&2; exit 1; }
args=()
if grep -qx 'CONFIG_CC_IS_CLANG=y' "$config"; then
    for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
        command -v "$tool" >/dev/null || { echo "Missing LLVM tool: $tool" >&2; exit 1; }
    done
    args=(LLVM=1 CC=clang)
elif grep -qx 'CONFIG_CC_IS_GCC=y' "$config"; then
    command -v gcc >/dev/null || { echo 'Missing GCC' >&2; exit 1; }
    args=(CC=gcc)
else
    echo 'Cannot identify kernel compiler from prepared headers; refusing to guess.' >&2
    exit 1
fi
if [[ ${3:-} == --check ]]; then
    printf 'Kernel build options: %s\n' "${args[*]}"
    exit 0
fi
exec make -C "$kernel_dir" M="$module_dir" "${args[@]}" EXTRA_CFLAGS='' modules
