#!/usr/bin/env bash
# Imperator // Λrca — floating personal-finance dashboard.
# Bound to left-click on Λ (custom/arca) in waybar.
#
# Opens a floating Kitty window (app-id arca-float, see niri rules) running the
# arca TUI, building it on first use if needed. Runs from the project root so
# arca's relative asset paths (the movements CSV, plan_state.json,
# egresos_log.csv, cuentas.json) resolve — arca both reads and writes them.
set -euo pipefail

export ARCA_DIR="$HOME/Projects/Λrca"

exec kitty \
    --app-id arca-float \
    --title "Λrca" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    --override "font_size=9.0" \
    bash -lc '
        cd "$ARCA_DIR" 2>/dev/null || {
            notify-send -u critical "Λrca" "Project not found at $ARCA_DIR"
            exec sleep 5
        }
        BIN="$ARCA_DIR/target/release/arca"
        if [[ ! -x "$BIN" ]]; then
            echo "Building arca (first run, ~30 s)…"
            cargo build --release || {
                echo "Build failed. Press Enter to close."
                read -r
                exit 1
            }
        fi
        exec "$BIN"
    '
