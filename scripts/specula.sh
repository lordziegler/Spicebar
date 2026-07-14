#!/usr/bin/env bash
# Specula Imperii — the productivity dashboard, in a floating Kitty window.
#
# Bound to the middle click of the GitHub module, which is its closest relative:
# CODEX draws exactly the contribution calendar that module sparks.
#
# It toggles. A second middle click closes the window rather than opening a
# second one — a dashboard you have three copies of is a dashboard you have
# stopped reading.

set -euo pipefail

APP_ID="specula-float"
REPO="$HOME/Projects/Specula-Imperii"

# Already on screen? Then this click means "put it away".
#
# By its pid, not with `niri msg action close-window`: that sends the compositor's
# polite close *request*, and a terminal running a full-screen TUI does not always
# take it — the window stayed open and a second click opened a third. A TERM to the
# terminal itself is the thing that actually ends.
open_pid="$(niri msg --json windows |
	jq -r --arg app "$APP_ID" 'first(.[] | select(.app_id == $app) | .pid) // empty')"

if [[ -n "$open_pid" ]]; then
	kill "$open_pid"
	exit 0
fi

# Installed on PATH if it ever gets there; otherwise the release build in the repo.
BINARY="$(command -v specula-imperii || true)"
[[ -z "$BINARY" && -x "$REPO/target/release/specula-imperii" ]] &&
	BINARY="$REPO/target/release/specula-imperii"

if [[ -z "$BINARY" ]]; then
	notify-send -u critical "Specula Imperii" \
		"No binary. Build it:  cd $REPO && cargo build --release"
	exit 1
fi

# The dashboard paints its own palette (amber on warm obsidian) — Kitty only has
# to get out of the way and give it the columns. It wants 137 at a minimum; at
# font_size 10 the 1400px window in the niri rule is good for about 170.
exec kitty \
	--app-id "$APP_ID" \
	--title "Specula Imperii" \
	--override font_size=10 \
	--override background=#070502 \
	--override cursor_shape=block \
	"$BINARY"
