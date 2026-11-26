#!/usr/bin/env bash
# Unit-тесты движка: tools/test.sh [фильтр]
set -euo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
timeout 600 "$G" --headless --path . --script res://tests/run_tests.gd -- "$@" 2>&1 | grep -vE "^(Godot Engine|WARNING: .*audio|   at: )|audio_driver|All audio drivers"
exit "${PIPESTATUS[0]}"
