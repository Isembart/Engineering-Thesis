#!/bin/bash
# Build the firmware and save it as <version>.bin, the name the server expects in its
# FIRMWARE_DIR. Copy the file there to release it to the boards.
# Usage: ./publish.sh [output-dir]     (default: board/.pio/release)
set -euo pipefail

cd "$(dirname "$0")"
out="${1:-.pio/release}"

# The version is the commit count (see platformio.ini), so the build must match a commit
if [ -n "$(git status --porcelain -- .)" ]; then
    echo "Uncommitted changes in board/, commit them before publishing:" >&2
    git status --short -- . >&2
    exit 1
fi

version=$(git rev-list --count HEAD)
pio run

mkdir -p "$out"
cp .pio/build/seeed_xiao_esp32_c6/firmware.bin "$out/$version.bin"
echo "Firmware version $version saved to $(realpath "$out/$version.bin")"