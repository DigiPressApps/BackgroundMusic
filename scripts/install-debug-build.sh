#!/bin/bash
# Install Debug build products for local testing (DPA fork).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="${ROOT}/BGMApp/build/Debug/Background Music.app"
DRIVER_SRC="${ROOT}/BGMDriver/build/Debug/Background Music Device.driver"
XPC_SRC="${ROOT}/BGMApp/build/Debug/BGMXPCHelper.xpc"
XPC_DST="/usr/local/libexec"
RESOURCES="${ROOT}/BGMApp/BGMXPCHelper"

for p in "$APP_SRC" "$DRIVER_SRC" "$XPC_SRC"; do
  if [[ ! -d "$p" ]]; then
    echo "Missing build product: $p" >&2
    exit 1
  fi
done

echo "Quitting Background Music if running..."
osascript -e 'quit app "Background Music"' 2>/dev/null || true
sleep 1

echo "Installing Background Music.app..."
rm -rf "/Applications/Background Music.app"
cp -R "$APP_SRC" "/Applications/"
# Prefer the invoking console user when this script is run via osascript admin.
CONSOLE_USER="$(stat -f %Su /dev/console 2>/dev/null || echo "")"
if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" ]]; then
  chown -R "${CONSOLE_USER}:admin" "/Applications/Background Music.app"
fi
xattr -dr com.apple.quarantine "/Applications/Background Music.app" 2>/dev/null || true

echo "Installing Background Music Device.driver..."
rm -rf "/Library/Audio/Plug-Ins/HAL/Background Music Device.driver"
cp -R "$DRIVER_SRC" "/Library/Audio/Plug-Ins/HAL/"
xattr -dr com.apple.quarantine "/Library/Audio/Plug-Ins/HAL/Background Music Device.driver" 2>/dev/null || true

echo "Installing BGMXPCHelper.xpc to ${XPC_DST}..."
mkdir -p "$XPC_DST"
rm -rf "${XPC_DST}/BGMXPCHelper.xpc"
cp -R "$XPC_SRC" "${XPC_DST}/"
xattr -dr com.apple.quarantine "${XPC_DST}/BGMXPCHelper.xpc" 2>/dev/null || true

echo "Running XPC helper post_install..."
bash "${RESOURCES}/post_install.sh" \
  "$XPC_DST" \
  "BGMXPCHelper.xpc/Contents/MacOS/BGMXPCHelper" \
  "$RESOURCES"

echo "Restarting coreaudiod..."
# Prefer kill over kickstart; kickstart can fail under SIP when invoked from some contexts.
killall coreaudiod 2>/dev/null || true
sleep 2

APP_VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "/Applications/Background Music.app/Contents/Info.plist")"
DRV_VER="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "/Library/Audio/Plug-Ins/HAL/Background Music Device.driver/Contents/Info.plist")"
echo "Installed app=${APP_VER} driver=${DRV_VER}"
echo "Done. Launch Background Music from Applications (do not open as root)."
