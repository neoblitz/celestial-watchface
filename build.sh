#!/usr/bin/env bash
# Build the Mars Gale Time watchface into a sideloadable .prg
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
KEY="developer_key.der"
OUT="bin/CelestialWatchface.prg"
DEVICE="venu3"

# --- Developer key (one-time) ---
if [[ ! -f "$KEY" ]]; then
  echo "Generating a one-time developer signing key ($KEY)..."
  openssl genrsa -out developer_key.pem 4096
  openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
          -out "$KEY" -nocrypt
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
