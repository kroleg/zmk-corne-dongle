#!/bin/bash
set -e

WORKSPACE="${PWD}/build"
LOCAL_MODULE="../zmk-dongle-display"
mkdir -p "$WORKSPACE"

# Sync config to workspace
rsync -a --delete config/ "$WORKSPACE/config/"

# Check if using local module
USE_LOCAL=""
if [ -d "$LOCAL_MODULE" ]; then
  echo "Will use local zmk-dongle-display module"
  USE_LOCAL=1
fi

docker run --rm \
  -v "$WORKSPACE:/workspaces/zmk" \
  -w /workspaces/zmk \
  -e ZEPHYR_BASE=/workspaces/zmk/zephyr \
  zmkfirmware/zmk-dev-arm:stable \
  /bin/bash -c "
    if [ ! -d .west ]; then
      west init -l config
    fi
    west update
    west zephyr-export
  "

# Overwrite with local module after west update
if [ -n "$USE_LOCAL" ]; then
  echo "Syncing local zmk-dongle-display..."
  rsync -a --delete "$LOCAL_MODULE/" "$WORKSPACE/zmk-dongle-display/"
fi

docker run --rm \
  -v "$WORKSPACE:/workspaces/zmk" \
  -w /workspaces/zmk \
  -e ZEPHYR_BASE=/workspaces/zmk/zephyr \
  zmkfirmware/zmk-dev-arm:stable \
  /bin/bash -c "
    west zephyr-export
    west build -p -b nice_nano_v2 -s zmk/app -- \
      -DSHIELD='eyeslash_corne_central_dongle dongle_display' \
      -DZMK_CONFIG=/workspaces/zmk/config \
      -DSNIPPET=studio-rpc-usb-uart \
      -DCONFIG_ZMK_STUDIO=y \
      -DCONFIG_ZMK_STUDIO_LOCKING=n
  "

cp "$WORKSPACE/build/zephyr/zmk.uf2" eyeslash_corne_dongle.uf2
echo "Done! Firmware: eyeslash_corne_dongle.uf2"
