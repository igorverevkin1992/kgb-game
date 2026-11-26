#!/usr/bin/env bash
# Сборки игры: tools/export.sh windows | web | all  → build/windows/LiniyaKR.exe, build/web/
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh templates)
what=${1:-all}
code=0
if [ "$what" = windows ] || [ "$what" = all ]; then
  mkdir -p build/windows
  timeout 600 "$G" --headless --path . --export-release "Windows Desktop" build/windows/LiniyaKR.exe 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f build/windows/LiniyaKR.exe ] && ls -la build/windows/LiniyaKR.exe || code=1
fi
if [ "$what" = web ] || [ "$what" = all ]; then
  mkdir -p build/web
  timeout 600 "$G" --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f build/web/index.html ] && ls -la build/web | head || code=1
fi
exit $code
