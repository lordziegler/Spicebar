#!/usr/bin/env bash
# GitHub — sparkline de contribuciones para la barra (JSON para waybar).
#
# El calendario del año completo vive en github-graph.sh, que abre el click
# izquierdo de este módulo. Esto solo dibuja la tendencia reciente: pequeño,
# una sola línea JSON, y nunca se bloquea (aquel usa `read` y por eso jamás
# sirvió como `exec`). Ningún número es inventado — si GitHub no responde, el
# módulo se oculta en vez de mentir un cero.

set -euo pipefail

USER="lordziegler"
GLYPH_FONT="JetBrainsMonoNL Nerd Font Propo 13"
ICON=$(printf '') # nf-fa-github
WINDOW=21               # días recientes en el sparkline de la barra

# Ante cualquier fallo, un módulo vacío (class oculta) en vez de un dato falso.
fail() { printf '{"text":"","class":"github-off","tooltip":"GitHub: %s"}\n' "$1"; exit 0; }

command -v gh >/dev/null 2>&1 || fail "gh no instalado"

YEAR=$(date +%Y)
TODAY=$(date +%Y-%m-%d)

DATA=$(gh api graphql -f query="
{ user(login: \"$USER\") {
    contributionsCollection(from: \"${YEAR}-01-01T00:00:00Z\", to: \"${YEAR}-12-31T23:59:59Z\") {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { contributionCount date } }
      } } } }" 2>/dev/null) || fail "sin conexión"

printf '%s\n' "$DATA" | jq -e '.data.user.contributionsCollection' >/dev/null 2>&1 || fail "sin datos"

printf '%s\n' "$DATA" | jq -c \
  --arg today "$TODAY" --arg icon "$ICON" --arg font "$GLYPH_FONT" --argjson window "$WINDOW" '
  .data.user.contributionsCollection.contributionCalendar as $cal
  | [ $cal.weeks[].contributionDays[] | select(.date <= $today) ] | sort_by(.date) as $days
  | ($cal.totalContributions) as $total
  | ($days[- $window :] | map(.contributionCount)) as $recent
  | (($recent | max) // 0) as $peak
  | ["▁","▂","▃","▄","▅","▆","▇","█"] as $blocks
  | ( $recent | map( if $peak == 0 then $blocks[0]
                     else $blocks[ (. * 7 / $peak) | round ] end ) | join("") ) as $spark
  | (($days[-1].contributionCount) // 0) as $today_count
  # Racha actual: se cuenta hacia atrás desde el último día mientras haya > 0.
  | ( reduce ($days | reverse | .[]) as $d ({run:0, done:false};
        if .done then .
        elif $d.contributionCount > 0 then {run: (.run + 1), done:false}
        else {run: .run, done:true} end) ).run as $streak
  | { text: "<span font=\"\($font)\">\($icon)</span> \($spark)",
      tooltip: "GitHub · \($total) contribuciones en \($today[0:4])\nRacha \($streak) d  ·  hoy \($today_count)  ·  últimos \($recent | length) d",
      class: "github" }
'
