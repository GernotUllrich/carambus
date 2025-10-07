#!/usr/bin/env bash
set -euo pipefail

# Detect IPv4 literals in source/templates, excluding known generated or logs
# Allowed paths (excluded): site/, public/, carambus_data/cursor_chats/

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Scanning for hard-coded IP addresses..."

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required. Please install rg."
  exit 2
fi

PATTERN='\b\d{1,3}(?:\.\d{1,3}){3}\b'

mkdir -p "$ROOT_DIR/tmp"

rg --regexp "$PATTERN" \
   --ignore-file "$ROOT_DIR/.gitignore" \
   --glob '!**/site/**' \
   --glob '!**/public/**' \
   --glob '!**/carambus_data/cursor_chats/**' \
   --glob '!**/config/deploy/**' \
   --glob '!**/config/*.erb' \
   --glob '!**/*.log' \
   --glob '!**/*.lock' \
   --glob '!**/*.png' \
   --glob '!**/*.svg' \
   --glob '!**/*.jpg' \
   --glob '!**/*.jpeg' \
   --glob '!**/*.gif' \
   --hidden \
   --line-number \
   --color never \
   "$ROOT_DIR" || true > "$ROOT_DIR/tmp/ip-literals.txt"

if [[ -s "$ROOT_DIR/tmp/ip-literals.txt" ]]; then
  echo "\n❌ Found potential hard-coded IP addresses:"
  cat "$ROOT_DIR/tmp/ip-literals.txt"
  echo "\nFailing check. Add variables/configs instead of literals, or whitelist via script if truly necessary."
  exit 1
else
  echo "✅ No hard-coded IP addresses found in source/templates."
fi


