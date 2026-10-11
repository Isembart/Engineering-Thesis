#!/bin/bash
# Build the firmware and publish it to the server's FIRMWARE_DIR.
# Usage: ./publish.sh user@host /path/to/server/firmware [ssh-port]
set -euo pipefail

host="$1"
dir="$2"
port="${3:-22}"
cd "$(dirname "$0")"

# The version is the commit count (see platformio.ini), so the build must match a commit
if [ -n "$(git status --porcelain -- .)" ]; then
    echo "Uncommitted changes in board/, commit them before publishing:" >&2
    git status --short -- . >&2
    exit 1
fi

version=$(git rev-list --count HEAD)
pio run

# Upload under a temporary name, boards only ever see complete <version>.bin files
scp -P "$port" .pio/build/seeed_xiao_esp32_c6/firmware.bin "$host:$dir/$version.bin.part"
ssh -p "$port" "$host" "mv '$dir/$version.bin.part' '$dir/$version.bin'"
echo "Published firmware version $version"
