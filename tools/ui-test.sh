#!/usr/bin/env bash
# Сценарии интерфейса под виртуальным экраном (Xvfb + OpenGL), скриншоты в build/screens/.
#   tools/ui-test.sh [фильтр]
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
LOG=$(mktemp)
timeout 900 xvfb-run -a -s "-screen 0 1600x900x24" "$G" --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1600x900 \
  res://tests/ui/run_ui_tests.tscn -- "$@" 2>&1 | tee "$LOG" | grep -vE "audio|ALSA|V-Sync|   at: |^Godot Engine|OpenGL API|^$"
code=${PIPESTATUS[0]}
# Ошибка скрипта обрывает сценарий молча — считаем её провалом прогона.
if grep -q "SCRIPT ERROR" "$LOG"; then echo "✗ В выводе есть SCRIPT ERROR — прогон считается проваленным"; exit 1; fi
exit "$code"
