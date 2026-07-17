#!/bin/zsh
cd "${0:A:h}"
APP_EXEC="实时网速监控.app/Contents/MacOS/NetworkSpeedMonitor"
if [[ ! -x "$APP_EXEC" || NetworkSpeedMonitor.m -nt "$APP_EXEC" ]]; then
  ./build_app.sh || exit 1
fi
exec "$APP_EXEC"
