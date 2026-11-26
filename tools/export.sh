#!/usr/bin/env bash
# Сборки игры: tools/export.sh windows | web | all  → build/windows/LiniyaKR.exe, build/web/
# Windows-сборка подключает GodotSteam (tools/get-godotsteam.sh), если архив доступен; без него —
# сборка без Steam. Веб-версия собирается без GodotSteam (GDExtension в вебе не работает).
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh templates)
what=${1:-all}
code=0
if [ "$what" = web ] || [ "$what" = all ]; then
  hidden=""
  if [ -d addons/godotsteam ]; then mv addons/godotsteam .godotsteam.off; hidden=1; fi
  mkdir -p build/web
  timeout 600 "$G" --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f build/web/index.html ] && ls -la build/web | head || code=1
  [ -n "$hidden" ] && mv .godotsteam.off addons/godotsteam
fi
if [ "$what" = windows ] || [ "$what" = all ]; then
  mkdir -p build/windows
  if tools/get-godotsteam.sh; then
    timeout 300 "$G" --headless --path . --import > /dev/null 2>&1 || true
  else
    echo "⚠ Сборка без Steam: GodotSteam недоступен"
  fi
  timeout 600 "$G" --headless --path . --export-release "Windows Desktop" build/windows/LiniyaKR.exe 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  # Для проверки Steam Overlay без своей страницы в Steam: тестовое приложение Valve «Spacewar» (480).
  echo 480 > build/windows/steam_appid.txt
  [ -f build/windows/LiniyaKR.exe ] && ls -la build/windows/ || code=1
fi
exit $code
