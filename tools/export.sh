#!/usr/bin/env bash
# Сборки игры: tools/export.sh windows | web | all  → build/windows/GodShpionov.exe, build/web/
# Windows-сборка — на шаблоне GodotSteam (Godot со встроенным Steam, tools/get-godotsteam.sh), если
# он доступен; рядом кладутся steam_api64.dll и steam_appid.txt. Без шаблона — сборка без Steam.
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh templates)
what=${1:-all}
code=0
if [ "$what" = windows ] || [ "$what" = all ]; then
  mkdir -p build/windows
  preset=export_presets.cfg
  steam_tpl=$(tools/get-godotsteam.sh 2>/dev/null || true)
  if [ -n "$steam_tpl" ] && [ -f "$steam_tpl" ]; then
    # Шаблон подставляется только на время сборки: в репозитории пресет без него.
    cp "$preset" "$preset.bak"
    sed -i "/^binary_format\/embed_pck=true/a custom_template/release=\"$steam_tpl\"" "$preset"
    trap 'mv -f export_presets.cfg.bak export_presets.cfg' EXIT
    cp "$(dirname "$steam_tpl")/steam_api64.dll" build/windows/
    # Для проверки Steam Overlay без своей страницы в Steam: тестовое приложение Valve «Spacewar» (480).
    echo 480 > build/windows/steam_appid.txt
    echo "Сборка со Steam: $(basename "$steam_tpl")"
  else
    echo "⚠ Сборка без Steam: шаблон GodotSteam недоступен"
  fi
  timeout 600 "$G" --headless --path . --export-release "Windows Desktop" build/windows/GodShpionov.exe 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f "$preset.bak" ] && mv -f "$preset.bak" "$preset"
  trap - EXIT
  [ -f build/windows/GodShpionov.exe ] && ls -la build/windows/ || code=1
fi
if [ "$what" = web ] || [ "$what" = all ]; then
  mkdir -p build/web
  timeout 600 "$G" --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f build/web/index.html ] && ls -la build/web | head || code=1
fi
exit $code
