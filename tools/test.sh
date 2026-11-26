#!/usr/bin/env bash
# Unit-тесты движка: tools/test.sh [фильтр]
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
LOG=$(mktemp)
timeout 600 "$G" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG" | grep -vE "^(Godot Engine|WARNING: .*audio|   at: )|audio_driver|All audio drivers"
code=${PIPESTATUS[0]}
# Ошибка скрипта обрывает сценарий молча — считаем её провалом прогона.
if grep -q "SCRIPT ERROR" "$LOG"; then echo "✗ В выводе есть SCRIPT ERROR — прогон считается проваленным"; exit 1; fi
exit "$code"
