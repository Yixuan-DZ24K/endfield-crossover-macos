#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Yixuan Zhang
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_BUILD="$TASK_ROOT/build"
mkdir -p "$TASK_BUILD"
/usr/bin/clang -arch x86_64 -dynamiclib -fobjc-arc -Wall -Wextra \
  -mmacosx-version-min=15.0 -I "$TASK_ROOT/src" \
  "$TASK_ROOT/src/EndfieldNotch.m" -framework AppKit -framework Foundation \
  -framework CoreGraphics -install_name '@rpath/EndfieldNotch.dylib' \
  -o "$TASK_BUILD/EndfieldNotch.dylib"
/usr/bin/clang -arch x86_64 -dynamiclib -fblocks -Wall -Wextra \
  -mmacosx-version-min=15.0 "$TASK_ROOT/src/loader.c" \
  -install_name '@rpath/EndfieldNotchLoader.dylib' \
  -o "$TASK_BUILD/EndfieldNotchLoader.dylib"
for task_library in EndfieldNotch.dylib EndfieldNotchLoader.dylib; do
  /usr/bin/codesign --force --sign - --timestamp=none "$TASK_BUILD/$task_library"
  /usr/bin/codesign --verify --strict "$TASK_BUILD/$task_library"
done
printf '%s\n' 'Built and ad-hoc signed the x86_64 compatibility libraries in build/.'
printf '%s\n' 'Build only: the installed CrossOver application and Bottles are not modified.'
