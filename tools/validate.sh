#!/usr/bin/env bash
# Проверка контента: tools/validate.sh [--dir=путь] [--en]
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
timeout 300 "$G" --headless --path . --script res://tools/validate.gd -- "$@" 2>&1 | grep -vE "^(Godot Engine|WARNING: .*audio|   at:)" 
exit "${PIPESTATUS[0]}"
