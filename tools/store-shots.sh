#!/usr/bin/env bash
# Скриншоты для страницы в Steam и VK Play: сценарии интерфейса в 1920×1080 (Steam требует не
# меньше 1920×1080 для 16:9), затем отбор и нумерация кадров → build/store/screenshots/.
#   tools/store-shots.sh
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
RAW="$PWD/build/store/raw"
OUT=build/store/screenshots
rm -rf "$RAW" "$OUT"; mkdir -p "$RAW" "$OUT"
UI_SHOTS_DIR="$RAW" timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --path . --rendering-driver opengl3 \
  --audio-driver Dummy --resolution 1920x1080 res://tests/ui/run_ui_tests.tscn 2>&1 | grep -E "Сценарии интерфейса|✗"
# Порядок кадров на странице: стол, маршрут, доска мотивов, шифрпункт, беседа, деньги, «Список»,
# полиграф, решение, документ, архив. Список правится здесь. Часть сценариев рассчитана на
# 1600×900 и в этом разрешении падает — на кадры это не влияет.
n=1
for f in desk-crt map-sdr-verdict board-analysis acceptance-ciphergram dialog-caldwell finance-tranche \
         counterintel-list polygraph-spike decision doc-chunk archive-epilogue; do
  if [ -f "$RAW/$f.png" ]; then cp "$RAW/$f.png" "$OUT/$(printf %02d $n)-$f.png"; n=$((n+1)); else echo "⚠ нет кадра $f"; fi
done
python3 - "$OUT" <<'PY'
import struct, sys, pathlib
for p in sorted(pathlib.Path(sys.argv[1]).glob("*.png")):
    w, h = struct.unpack(">II", p.read_bytes()[16:24])
    print(f"{p.name}: {w}×{h}" + ("" if (w, h) >= (1920, 1080) else "  ⚠ меньше 1920×1080"))
PY
