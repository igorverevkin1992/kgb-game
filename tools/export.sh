#!/usr/bin/env bash
# Сборки игры: tools/export.sh windows | demo | web | all
#   windows → build/windows/GodShpionov.exe, demo → build/windows-demo/GodShpionovDemo.exe
#   (признак demo: кампания заканчивается после фазы campaign.demo.last_act), web → build/web/.
# Windows-сборки — на шаблоне GodotSteam (Godot со встроенным Steam, tools/get-godotsteam.sh), если
# он доступен; рядом кладутся steam_api64.dll и steam_appid.txt. Без шаблона — сборка без Steam.
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh templates)
what=${1:-all}
code=0
preset=export_presets.cfg
steam_tpl=""

# Шаблон GodotSteam подставляется только на время сборки: в репозитории пресеты без него.
use_steam_template() {
  steam_tpl=$(tools/get-godotsteam.sh 2>/dev/null || true)
  if [ -n "$steam_tpl" ] && [ -f "$steam_tpl" ]; then
    cp "$preset" "$preset.bak"
    sed -i "/^binary_format\/embed_pck=true/a custom_template/release=\"$steam_tpl\"" "$preset"
    trap 'mv -f export_presets.cfg.bak export_presets.cfg' EXIT
    echo "Сборка со Steam: $(basename "$steam_tpl")"
  else
    steam_tpl=""
    echo "⚠ Сборка без Steam: шаблон GodotSteam недоступен"
  fi
}

build_windows() {  # пресет, папка, файл
  mkdir -p "$2"
  if [ -n "$steam_tpl" ]; then
    cp "$(dirname "$steam_tpl")/steam_api64.dll" "$2/"
    # Для проверки Steam Overlay без своей страницы в Steam: тестовое приложение Valve «Spacewar» (480).
    echo 480 > "$2/steam_appid.txt"
  fi
  timeout 600 "$G" --headless --path . --export-release "$1" "$2/$3" 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f "$2/$3" ] && ls -la "$2/" || code=1
}

if [ "$what" = windows ] || [ "$what" = demo ] || [ "$what" = all ]; then
  use_steam_template
  if [ "$what" != demo ]; then build_windows "Windows Desktop" build/windows GodShpionov.exe; fi
  if [ "$what" != windows ]; then build_windows "Windows Demo" build/windows-demo GodShpionovDemo.exe; fi
  [ -f "$preset.bak" ] && mv -f "$preset.bak" "$preset"
  trap - EXIT
fi
if [ "$what" = web ] || [ "$what" = all ]; then
  mkdir -p build/web
  timeout 600 "$G" --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "audio|   at: " | tail -5 || true
  [ -f build/web/index.html ] && ls -la build/web | head || code=1
fi
exit $code
