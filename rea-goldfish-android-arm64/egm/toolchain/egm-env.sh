#!/data/data/com.termux/files/usr/bin/env bash
# Sourced by scripts/*.sh. All paths live inside Termux's own filesystem so
# regular files and permission bits behave normally (no /sdcard FUSE quirks).

export EGM_ANDROID_ROOT="${EGM_ANDROID_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export EGM_BUNDLE_DIR="${EGM_BUNDLE_DIR:-$HOME/.local/share/egm-android-arm64/bundle}"
export OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
