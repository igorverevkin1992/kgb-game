#!/usr/bin/env bash
# Скачивает GodotSteam (GDExtension) из релиза этого репозитория в addons/godotsteam/ (в git не
# хранится). Нужен только для Windows-сборки: без него игра работает, но без Steam.
# Код возврата 1 — архива нет (запустите workflow «Godot tools»).
set -euo pipefail
cd "$(dirname "$0")/.."
V=$(cat tools/godotsteam-version.txt)
TAG="godotsteam-$V"
REPO=igorverevkin1992/kgb-game
[ -f addons/godotsteam/godotsteam.gdextension ] && { echo "addons/godotsteam уже на месте"; exit 0; }
id=$(gh api "repos/$REPO/releases/tags/$TAG" --jq '.assets[] | select(.name == "godotsteam-gdextension.zip") | .id' 2>/dev/null || true)
[ -n "$id" ] || { echo "Нет релиза $TAG с GodotSteam (запустите workflow «Godot tools»)" >&2; exit 1; }
tmp=$(mktemp -d)
gh api -H "Accept: application/octet-stream" "repos/$REPO/releases/assets/$id" > "$tmp/gs.zip"
unzip -o -q "$tmp/gs.zip" -d "$tmp/x"
src=$(dirname "$(find "$tmp/x" -name 'godotsteam.gdextension' | head -1)")
[ -d "$src" ] || { echo "В архиве нет godotsteam.gdextension" >&2; exit 1; }
mkdir -p addons
rm -rf addons/godotsteam
cp -r "$src" addons/godotsteam
rm -rf "$tmp"
echo "GodotSteam $V: addons/godotsteam"
