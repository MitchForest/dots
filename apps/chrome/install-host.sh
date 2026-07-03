#!/bin/zsh
# Installs the Dots capture host for Chrome.
# Usage: ./install-host.sh <chrome-extension-id>
# (Load apps/chrome unpacked via chrome://extensions → copy its ID.)
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <chrome-extension-id>" >&2
  exit 1
fi
EXTENSION_ID="$1"
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

echo "▸ building dots-capture-host (release)"
swift build --package-path "$REPO_ROOT/tools/dots-capture-host" -c release

HOST_DIR="$HOME/Library/Application Support/Dots"
mkdir -p "$HOST_DIR"
cp "$REPO_ROOT/tools/dots-capture-host/.build/release/dots-capture-host" "$HOST_DIR/"

MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
mkdir -p "$MANIFEST_DIR"
cat > "$MANIFEST_DIR/blog.dots.capture.json" <<MANIFEST
{
  "name": "blog.dots.capture",
  "description": "Dots capture host — writes captures into your vault.",
  "path": "$HOST_DIR/dots-capture-host",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/"]
}
MANIFEST

echo "✓ host installed for extension $EXTENSION_ID"
echo "  restart Chrome, then click the Dots button (or ⌥⇧D) on any page"
