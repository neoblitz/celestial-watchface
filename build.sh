#!/usr/bin/env bash
# Build the Celestial Watchface into a sideloadable .prg
# Usage: ./build.sh            # build release .prg for venu3
#        ./build.sh sim        # build + launch in the simulator
set -euo pipefail

cd "$(dirname "$0")"

# --- Locate the Connect IQ SDK ---
# The SDK Manager stores the active SDK path here:
CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
if [[ -f "$CFG" ]]; then
  SDK="$(tr -d '\n' < "$CFG")"
else
  SDK="${CIQ_HOME:-}"
fi
if [[ -z "${SDK:-}" || ! -x "$SDK/bin/monkeyc" ]]; then
  echo "ERROR: Connect IQ SDK not found."
  echo "Install it (see README.md), then re-run. Looked at: $CFG"
  exit 1
fi
echo "Using SDK: $SDK"

MONKEYC="$SDK/bin/monkeyc"
OUT="bin/CelestialWatchface.prg"
DEVICE="venu3"

# --- Developer signing key ---
# Kept OUTSIDE this (Dropbox-synced) project so the private key never syncs to
# the cloud. Override with CIQ_KEY=/path/to/key.der if you store it elsewhere.
KEY="${CIQ_KEY:-$HOME/.garmin/celestial/developer_key.der}"
if [[ ! -f "$KEY" ]]; then
  echo "ERROR: signing key not found at: $KEY"
  echo "This app is already published — do NOT generate a new key (that would"
  echo "create a different identity and break store updates)."
  echo "Restore developer_key.pem from 1Password, then run:"
  echo "  mkdir -p \"\$HOME/.garmin/celestial\""
  echo "  openssl pkcs8 -topk8 -inform PEM -outform DER \\"
  echo "    -in developer_key.pem -out \"$KEY\" -nocrypt"
  echo "  chmod 600 \"$KEY\""
  exit 1
fi

mkdir -p bin

"$MONKEYC" \
  --jungles monkey.jungle \
  --device "$DEVICE" \
  --output "$OUT" \
  --private-key "$KEY" \
  --warn

echo "Built: $OUT"

if [[ "${1:-}" == "sim" ]]; then
  echo "Launching simulator..."
  "$SDK/bin/connectiq" &
  sleep 4
  "$SDK/bin/monkeydo" "$OUT" "$DEVICE"
fi
