#!/usr/bin/env bash
# Unit-тесты движка: tools/test.sh [фильтр]
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
LOG=$(mktemp)
# Сначала — компилируются ли все скрипты (скрипт с ошибкой в сцене заставляет Godot висеть).
timeout 120 "$G" --headless --path . --audio-driver Dummy res://tools/check_scripts.tscn > "$LOG.check" 2>&1
ccode=$?
grep -E "SCRIPT ERROR|at: GDScript|Скрипты|Не компилируются|^  res://" "$LOG.check"
if [ "$ccode" != "0" ] || grep -q "SCRIPT ERROR" "$LOG.check"; then echo "✖ Проверка компиляции не прошла"; exit 1; fi
timeout 600 "$G" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1 | tee "$LOG" | grep -vE "^(Godot Engine|WARNING: .*audio|   at: )|audio_driver|All audio drivers"
code=${PIPESTATUS[0]}
# Ошибка скрипта обрывает сценарий молча — считаем её провалом прогона.
if grep -q "SCRIPT ERROR" "$LOG"; then echo "✗ В выводе есть SCRIPT ERROR — прогон считается проваленным"; exit 1; fi
exit "$code"
