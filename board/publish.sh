#!/bin/bash
# Build the firmware and publish it to the server's FIRMWARE_DIR.
# Usage: ./publish.sh user@host /path/to/server/firmware
set -euo pipefail

host="$1"
dir="$2"
cd "$(dirname "$0")"

version=$(awk '/#define FIRMWARE_VERSION/ {print $3}' src/version.h)
pio run

# Upload under a temporary name, boards only ever see complete <version>.bin files
scp .pio/build/seeed_xiao_esp32_c6/firmware.bin "$host:$dir/$version.bin.part"
ssh "$host" "mv '$dir/$version.bin.part' '$dir/$version.bin'"
echo "Published firmware version $version"
