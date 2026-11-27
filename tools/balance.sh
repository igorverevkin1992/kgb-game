#!/usr/bin/env bash
# Балансный прогон: автоигрок проходит всю кампанию тремя стратегиями (осторожно, спешка
# в финале, беспечно) через настоящий движок и печатает концовки, недели фаз и риски.
set -uo pipefail
cd "$(dirname "$0")/.."
G=$(tools/get-godot.sh)
timeout 300 "$G" --headless --path . --script res://tools/balance_run.gd 2>&1 | grep -vE "^(Godot Engine|WARNING|   at:)|ObjectDB"
