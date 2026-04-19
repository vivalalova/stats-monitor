#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

SCHEME="StatsMonitor"
WORKSPACE="StatsMonitor.xcworkspace"
CONFIGURATION="Release"
DERIVED_DATA="build"
APP_NAME="StatsMonitor.app"
INSTALL_PATH="/Applications/$APP_NAME"
ARCH="$(uname -m)"

echo "==> tuist generate"
tuist generate --no-open

echo "==> xcodebuild ($CONFIGURATION, arch=$ARCH)"
xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS,arch=$ARCH" \
    -derivedDataPath "$DERIVED_DATA" \
    clean build \
    | xcbeautify 2>/dev/null || true

BUILT_APP="$PROJECT_ROOT/$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME"
if [[ ! -d "$BUILT_APP" ]]; then
    echo "Error: build product not found at $BUILT_APP" >&2
    exit 1
fi

if pgrep -x "$SCHEME" >/dev/null; then
    echo "==> Quitting running $SCHEME"
    osascript -e "tell application \"$SCHEME\" to quit" >/dev/null 2>&1 || true
    sleep 1
fi

echo "==> Installing to $INSTALL_PATH"
rm -rf "$INSTALL_PATH"
cp -R "$BUILT_APP" "$INSTALL_PATH"

echo "==> Stripping quarantine attribute"
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "==> Launching"
open "$INSTALL_PATH"

echo "✓ Installed $APP_NAME to /Applications"
