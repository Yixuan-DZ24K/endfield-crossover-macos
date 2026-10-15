#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Yixuan Zhang
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: ./scripts/test.sh [--arch native|arm64|x86_64]

Compile and run the geometry and offscreen AppKit bridge tests on macOS.
The default is the shell's current architecture. Testing x86_64 on Apple
silicon requires Rosetta. No game, Bottle, or installed runtime is accessed.
Build products remain in build/tests/<architecture>/.
EOF
}

test_arch="$(uname -m)"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --arch)
            [[ $# -ge 2 ]] || { usage >&2; exit 2; }
            test_arch="$2"
            [[ "$test_arch" != native ]] || test_arch="$(uname -m)"
            shift 2
            ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

[[ "$(uname -s)" == Darwin ]] || { printf 'These tests require macOS and AppKit.\n' >&2; exit 1; }
case "$test_arch" in
    arm64|x86_64) ;;
    *) printf 'Unsupported test architecture: %s\n' "$test_arch" >&2; exit 2 ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="$repo_root/build/tests/$test_arch"
mkdir -p "$build_dir"
compiler="${CC:-$(xcrun --sdk macosx --find clang)}"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
common=(-arch "$test_arch" -isysroot "$sdk_path" -mmacosx-version-min=12.0
        -Wall -Wextra -Werror -I "$repo_root/src")

printf 'Building and running tests for %s with %s\n' "$test_arch" "$compiler"
"$compiler" "${common[@]}" -std=c11 "$repo_root/tests/geometry-test.c" \
    -framework CoreGraphics -o "$build_dir/geometry-test"
"$compiler" "${common[@]}" -fobjc-arc -fblocks "$repo_root/tests/bridge-test.m" \
    -framework AppKit -framework CoreGraphics -o "$build_dir/bridge-test"

"$build_dir/geometry-test"
# Disable automatic constructor setup; install once after the display fixture.
ENDFIELD_NOTCH_SAFE=0 "$build_dir/bridge-test"
printf 'All %s tests passed.\n' "$test_arch"
