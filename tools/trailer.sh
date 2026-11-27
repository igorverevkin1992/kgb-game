#!/usr/bin/env bash
# Черновой трейлер: Movie Maker Godot (постоянные 30 кадров/с, 1920×1080) → ffmpeg → H.264.
#   tools/trailer.sh  → build/store/trailer.mp4 (без звука; музыка и голос — при монтаже)
# Тексты титров и порядок экранов — в tools/trailer.gd (SHOTS, FINAL).
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
OUT=build/store
mkdir -p "$OUT"
rm -f "$OUT/trailer.avi" "$OUT/trailer.mp4"
timeout 1200 xvfb-run -a -s "-screen 0 1920x1080x24" "$G" --path . --rendering-driver opengl3 \
  --resolution 1920x1080 --write-movie "$PWD/$OUT/trailer.avi" --fixed-fps 30 res://tools/trailer.tscn 2>&1 \
  | grep -E "трейлер|SCRIPT ERROR" || true
[ -f "$OUT/trailer.avi" ] || { echo "✖ запись не получилась"; exit 1; }
ffmpeg -loglevel error -y -i "$OUT/trailer.avi" -an -c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p \
  -vf "scale=1920:1080:flags=lanczos" -movflags +faststart "$OUT/trailer.mp4"
rm -f "$OUT/trailer.avi"
ffprobe -v error -show_entries format=duration:stream=width,height,codec_name -of default=nw=1 "$OUT/trailer.mp4"
