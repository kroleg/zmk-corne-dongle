#!/bin/bash
set -e

WORKSPACE="${PWD}/build"
LOCAL_MODULE="../zmk-dongle-display"

# Parse arguments
BUILD_TARGET="${1:-all}"
SKIP_UPDATE=""

for arg in "$@"; do
  case "$arg" in
    --skip-update|-s)
      SKIP_UPDATE=1
      ;;
  esac
done

# Handle first positional arg for target
if [ "$1" = "--skip-update" ] || [ "$1" = "-s" ]; then
  BUILD_TARGET="all"
fi

show_help() {
  echo "Usage: ./build.sh [target] [options]"
  echo ""
  echo "Targets:"
  echo "  all          Build all components (default)"
  echo "  dongle       Build central dongle only"
  echo "  left         Build left peripheral only"
  echo "  right        Build right peripheral only"
  echo "  peripherals  Build both peripherals"
  echo ""
  echo "Options:"
  echo "  --skip-update, -s  Skip west update (faster rebuilds)"
  echo ""
}

if [ "$BUILD_TARGET" = "-h" ] || [ "$BUILD_TARGET" = "--help" ]; then
  show_help
  exit 0
fi

mkdir -p "$WORKSPACE"

# Sync config to workspace
rsync -a --delete config/ "$WORKSPACE/config/"

# Check if using local module
USE_LOCAL=""
if [ -d "$LOCAL_MODULE" ]; then
  echo "Will use local zmk-dongle-display module"
  USE_LOCAL=1
fi

# Initialize west workspace if needed
if [ -n "$SKIP_UPDATE" ] && [ -d "$WORKSPACE/.west" ]; then
  echo "Skipping west update (--skip-update)"
else
  echo "Initializing workspace..."
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
fi

# Overwrite with local module after west update
if [ -n "$USE_LOCAL" ]; then
  echo "Syncing local zmk-dongle-display..."
  rsync -a --delete "$LOCAL_MODULE/" "$WORKSPACE/zmk-dongle-display/"
fi

build_dongle() {
  echo ""
  echo "========================================="
  echo "Building: Central Dongle"
  echo "========================================="
  docker run --rm \
    -v "$WORKSPACE:/workspaces/zmk" \
    -w /workspaces/zmk \
    -e ZEPHYR_BASE=/workspaces/zmk/zephyr \
    zmkfirmware/zmk-dev-arm:stable \
    /bin/bash -c "
      west zephyr-export
      west build -p -b nice_nano_v2 -s zmk/app -d build/dongle -- \
        -DSHIELD='eyeslash_corne_central_dongle dongle_display' \
        -DZMK_CONFIG=/workspaces/zmk/config \
        -DSNIPPET=studio-rpc-usb-uart \
        -DCONFIG_ZMK_STUDIO=y \
        -DCONFIG_ZMK_STUDIO_LOCKING=n
    "
  cp "$WORKSPACE/build/dongle/zephyr/zmk.uf2" eyeslash_corne_dongle.uf2
  echo "Built: eyeslash_corne_dongle.uf2"
}

build_left() {
  echo ""
  echo "========================================="
  echo "Building: Left Peripheral"
  echo "========================================="
  docker run --rm \
    -v "$WORKSPACE:/workspaces/zmk" \
    -w /workspaces/zmk \
    -e ZEPHYR_BASE=/workspaces/zmk/zephyr \
    zmkfirmware/zmk-dev-arm:stable \
    /bin/bash -c "
      west zephyr-export
      west build -p -b nice_nano_v2 -s zmk/app -d build/left -- \
        -DSHIELD='eyeslash_corne_peripheral_left nice_view' \
        -DZMK_CONFIG=/workspaces/zmk/config
    "
  cp "$WORKSPACE/build/left/zephyr/zmk.uf2" eyeslash_corne_left.uf2
  echo "Built: eyeslash_corne_left.uf2"
}

build_right() {
  echo ""
  echo "========================================="
  echo "Building: Right Peripheral"
  echo "========================================="
  docker run --rm \
    -v "$WORKSPACE:/workspaces/zmk" \
    -w /workspaces/zmk \
    -e ZEPHYR_BASE=/workspaces/zmk/zephyr \
    zmkfirmware/zmk-dev-arm:stable \
    /bin/bash -c "
      west zephyr-export
      west build -p -b nice_nano_v2 -s zmk/app -d build/right -- \
        -DSHIELD='eyeslash_corne_peripheral_right nice_view' \
        -DZMK_CONFIG=/workspaces/zmk/config
    "
  cp "$WORKSPACE/build/right/zephyr/zmk.uf2" eyeslash_corne_right.uf2
  echo "Built: eyeslash_corne_right.uf2"
}

case "$BUILD_TARGET" in
  all)
    build_dongle
    build_left
    build_right
    ;;
  dongle)
    build_dongle
    ;;
  left)
    build_left
    ;;
  right)
    build_right
    ;;
  peripherals)
    build_left
    build_right
    ;;
  *)
    echo "Unknown target: $BUILD_TARGET"
    show_help
    exit 1
    ;;
esac

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
