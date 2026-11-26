#!/usr/bin/env bash
# Скачивает Godot (Linux-редактор) из релиза этого репозитория в .godot-bin/ и печатает путь.
#   tools/get-godot.sh            — только редактор
#   tools/get-godot.sh templates  — плюс шаблоны экспорта (для сборки .exe и веб-версии)
set -euo pipefail
cd "$(dirname "$0")/.."
V=$(cat tools/godot-version.txt)
TAG="godot-$V"
DIR=.godot-bin
REPO=igorverevkin1992/kgb-game

# Скачать файл релиза через REST API (GraphQL в облачной сессии недоступен).
fetch_asset() {
  local name="$1" out="$2" id
  id=$(gh api "repos/$REPO/releases/tags/$TAG" --jq ".assets[] | select(.name == \"$name\") | .id")
  [ -n "$id" ] || { echo "Нет файла $name в релизе $TAG (запустите workflow «Godot tools»)" >&2; exit 1; }
  gh api -H "Accept: application/octet-stream" "repos/$REPO/releases/assets/$id" > "$out"
}
BIN="$DIR/Godot_v${V}_linux.x86_64"
mkdir -p "$DIR"
if [ ! -x "$BIN" ]; then
  fetch_asset "Godot_v${V}_linux.x86_64.zip" "$DIR/Godot_v${V}_linux.x86_64.zip"
  (cd "$DIR" && unzip -o -q "Godot_v${V}_linux.x86_64.zip" && rm "Godot_v${V}_linux.x86_64.zip")
  chmod +x "$BIN"
fi
if [ "${1:-}" = "templates" ]; then
  TPL="$HOME/.local/share/godot/export_templates/${V/-/.}"
  if [ ! -d "$TPL" ]; then
    fetch_asset "Godot_v${V}_export_templates.tpz" "$DIR/Godot_v${V}_export_templates.tpz"
    mkdir -p "$TPL"
    unzip -o -q "$DIR/Godot_v${V}_export_templates.tpz" -d "$DIR/tpl" && mv "$DIR"/tpl/templates/* "$TPL"/ && rm -rf "$DIR/tpl" "$DIR/Godot_v${V}_export_templates.tpz"
  fi
fi
echo "$PWD/$BIN"
