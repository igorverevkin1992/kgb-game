#!/usr/bin/env bash
# Скачивает Godot (Linux-редактор) из релиза этого репозитория в .godot-bin/ и печатает путь.
#   tools/get-godot.sh            — только редактор
#   tools/get-godot.sh templates  — плюс шаблоны экспорта (для сборки .exe и веб-версии)
set -euo pipefail
cd "$(dirname "$0")/.."
V=$(cat tools/godot-version.txt)
TAG="godot-$V"
DIR=.godot-bin
BIN="$DIR/Godot_v${V}_linux.x86_64"
mkdir -p "$DIR"
if [ ! -x "$BIN" ]; then
  gh release download "$TAG" --repo igorverevkin1992/kgb-game --pattern "Godot_v${V}_linux.x86_64.zip" --dir "$DIR" --clobber >&2
  (cd "$DIR" && unzip -o -q "Godot_v${V}_linux.x86_64.zip" && rm "Godot_v${V}_linux.x86_64.zip")
  chmod +x "$BIN"
fi
if [ "${1:-}" = "templates" ]; then
  TPL="$HOME/.local/share/godot/export_templates/${V/-/.}"
  if [ ! -d "$TPL" ]; then
    gh release download "$TAG" --repo igorverevkin1992/kgb-game --pattern "Godot_v${V}_export_templates.tpz" --dir "$DIR" --clobber >&2
    mkdir -p "$TPL"
    unzip -o -q "$DIR/Godot_v${V}_export_templates.tpz" -d "$DIR/tpl" && mv "$DIR"/tpl/templates/* "$TPL"/ && rm -rf "$DIR/tpl" "$DIR/Godot_v${V}_export_templates.tpz"
  fi
fi
echo "$PWD/$BIN"
