#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/network-speed-release.XXXXXX")"
APP_DIR="$TEMP_DIR/实时网速监控.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/NetworkSpeedMonitor"
OUTPUT_DIR="$PROJECT_DIR/release"
OUTPUT_ZIP="$OUTPUT_DIR/实时网速监控-macOS-universal.zip"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$APP_DIR/Contents/MacOS" "$OUTPUT_DIR"
cp "$PROJECT_DIR/实时网速监控.app/Contents/Info.plist" "$APP_DIR/Contents/Info.plist"

CLANG_MODULE_CACHE_PATH="$TEMP_DIR/module-cache" \
  /usr/bin/xcrun clang -fobjc-arc -framework Cocoa \
  -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 \
  "$PROJECT_DIR/NetworkSpeedMonitor.m" -o "$EXECUTABLE"

chmod +x "$EXECUTABLE"
/usr/bin/xattr -cr "$APP_DIR"
/usr/bin/codesign --force --deep --sign - "$APP_DIR"
/usr/bin/codesign --verify --deep --strict "$APP_DIR"

/bin/rm -f "$OUTPUT_ZIP"
(cd "$TEMP_DIR" && COPYFILE_DISABLE=1 /usr/bin/zip -qry -X "$OUTPUT_ZIP" "实时网速监控.app")
echo "发布包已生成：$OUTPUT_ZIP"
