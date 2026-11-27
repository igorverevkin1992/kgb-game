#!/usr/bin/env bash
# Заглушки графики для магазинов (капсулы Steam, обложки VK Play) → build/store/art/.
# Нарисованы кодом шрифтами и палитрой игры; релизный арт — авторский (docs/store/assets.md).
#   tools/store-art.sh [имя …]   — все размеры или только указанные
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
mkdir -p build/store/art
timeout 300 xvfb-run -a -s "-screen 0 1600x900x24" "$G" --path . --rendering-driver opengl3 --audio-driver Dummy \
  res://tools/store_art.tscn -- "$@" 2>&1 | grep -E "×|ERROR"
