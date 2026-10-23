#!/bin/bash
# Parse the keymap with keymap-drawer (in Docker) and give the RU layer
# Cyrillic legends. Writes keymap-drawer/eyeslash_corne.{yaml,svg,json}.
# If the keymap viewer app exists (~/code/os/keymap), its JSON is refreshed and the app rebuilt.
set -e

cd "$(dirname "$0")/.."
OUT=keymap-drawer
SHIELD=config/boards/shields/eyeslash_corne
VIEWER="$HOME/code/os/keymap"

docker run --rm -v "$PWD:/repo" -w /repo python:3.12-slim sh -c "
  set -e
  pip install -q --root-user-action=ignore keymap-drawer >/dev/null 2>&1
  keymap -c keymap_drawer.config.yaml parse -z $SHIELD/eyeslash_corne.keymap > /tmp/parsed.yaml
  python $OUT/ru_legends.py /tmp/parsed.yaml $SHIELD/eyeslash_corne.keymap $SHIELD/eyeslash_corne-layouts.dtsi \
    $OUT/eyeslash_corne.yaml $OUT/eyeslash_corne.json
  keymap -c keymap_drawer.config.yaml draw -d $SHIELD/eyeslash_corne-layouts.dtsi $OUT/eyeslash_corne.yaml > $OUT/eyeslash_corne.svg
"

if [ -d "$VIEWER" ]; then
  cp "$OUT/eyeslash_corne.json" "$VIEWER/keymap.json"
  "$VIEWER/build.sh"
fi
echo "Drawn: $OUT/eyeslash_corne.{yaml,svg,json}"
