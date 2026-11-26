#!/usr/bin/env bash
# Сводка журналов плейтеста: tools/telemetry-report.sh [папка с session-*.jsonl]
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
args=()
[ $# -gt 0 ] && args=(-- "--dir=$(realpath "$1")")
timeout 120 "$G" --headless --path . --script res://tools/telemetry_report.gd "${args[@]}" 2>&1 | grep -vE "^(Godot Engine|WARNING: .*audio|   at:)"
