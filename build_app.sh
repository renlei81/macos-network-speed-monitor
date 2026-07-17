#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
APP_DIR="$PROJECT_DIR/实时网速监控.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/NetworkSpeedMonitor"
CACHE_DIR="${TMPDIR:-/tmp}/network-speed-clang-cache"

mkdir -p "$APP_DIR/Contents/MacOS" "$CACHE_DIR"
CLANG_MODULE_CACHE_PATH="$CACHE_DIR" \
  /usr/bin/xcrun clang -fobjc-arc -framework Cocoa \
  -arch arm64 -arch x86_64 \
  -mmacosx-version-min=11.0 \
  "$PROJECT_DIR/NetworkSpeedMonitor.m" -o "$EXECUTABLE"
chmod +x "$EXECUTABLE"
echo "构建完成：$APP_DIR"
