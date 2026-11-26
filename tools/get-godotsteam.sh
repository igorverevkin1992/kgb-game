#!/usr/bin/env bash
# Скачивает шаблон экспорта GodotSteam (Godot со встроенным Steam) для Windows из релиза этого
# репозитория в .godot-bin/godotsteam/ и печатает путь к шаблону. Код возврата 1 — архива нет
# (запустите workflow «Godot tools»). Без шаблона Windows-сборка собирается без Steam.
set -euo pipefail
cd "$(dirname "$0")/.."
V=$(cat tools/godotsteam-version.txt)
GV=$(sed 's/-stable//; s/\.//g' tools/godot-version.txt)
TAG="godotsteam-$V-g$GV"
REPO=igorverevkin1992/kgb-game
DIR=.godot-bin/godotsteam
TPL="$DIR/godotsteam.$GV.template.win64.exe"
if [ ! -f "$TPL" ]; then
  id=$(gh api "repos/$REPO/releases/tags/$TAG" --jq '.assets[] | select(.name == "godotsteam-templates.tar.xz") | .id' 2>/dev/null || true)
  [ -n "$id" ] || { echo "Нет релиза $TAG с шаблонами GodotSteam (запустите workflow «Godot tools»)" >&2; exit 1; }
  mkdir -p "$DIR"
  gh api -H "Accept: application/octet-stream" "repos/$REPO/releases/assets/$id" > "$DIR/t.tar.xz"
  tar -xJf "$DIR/t.tar.xz" -C "$DIR" --strip-components=1 win64/
  rm "$DIR/t.tar.xz"
fi
echo "$PWD/$TPL"
