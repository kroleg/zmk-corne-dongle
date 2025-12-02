# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

ZMK firmware configuration for an Eyeslash Corne split keyboard with wireless dongle. The keyboard uses:
- Nordic nRF52-based MCU (pro_micro compatible)
- Central USB dongle with SH1106 OLED display
- Two wireless peripheral halves (left/right)
- EC11 rotary encoder on left half
- WS2812 RGB underglow LEDs

## Build Process

Firmware builds automatically via GitHub Actions on push to main. The workflow uses ZMK's official `build-user-config.yml`.

To fetch the latest firmware artifacts:
```bash
./fetch-firmware.sh [output_dir]
```
Requires `GITHUB_TOKEN` in `.env` file. Downloads to `~/Downloads` by default.

## Architecture

### Key Files

- `eyeslash_corne.keymap` - Main keymap with layers and behaviors
- `eyeslash_corne.conf` - Global keyboard config (sleep timeout, display, encoder)
- `eyeslash_corne.dtsi` - Hardware definitions (matrix, encoder, LEDs)
- `west.yml` - ZMK and module dependencies

### Shield Components

The shield has three parts defined in `boards/shields/eyeslash_corne/`:
- `eyeslash_corne_central_dongle` - USB dongle (connects to host, has display)
- `eyeslash_corne_peripheral_left` - Left half with encoder
- `eyeslash_corne_peripheral_right` - Right half
