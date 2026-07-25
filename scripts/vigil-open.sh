#!/usr/bin/env bash
# Imperator // Vigil — floating agroclimatic monitoring dashboard.
# Bound to right-click on ♁ officium (custom/otium).
#
# Opens a floating Kitty window (app-id vigil-float, see niri rules) running the
# vigil binary, building it on first use if needed.
set -euo pipefail

export VIGIL_DIR="$HOME/Projects/vigil"

exec kitty \
    --app-id vigil-float \
    --title "Vigil" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    --override "font_size=9.0" \
    bash -lc '
        cd "$VIGIL_DIR" 2>/dev/null || {
            notify-send -u critical "Vigil" "Project not found at $VIGIL_DIR"
            exec sleep 5
        }
        BIN="$VIGIL_DIR/target/release/vigil"
        if [[ ! -x "$BIN" ]]; then
            echo "Building vigil (first run, ~30 s)…"
            cargo build --release || {
                echo "Build failed. Press Enter to close."
                read -r
                exit 1
            }
        fi
        exec "$BIN"
    '
