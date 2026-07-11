#!/usr/bin/env bash

YEAR=$(date +%Y)
FROM="${YEAR}-01-01T00:00:00Z"
TO="${YEAR}-12-31T23:59:59Z"

DATA=$(gh api graphql -f query="
{ user(login: \"lordziegler\") {
    contributionsCollection(from: \"$FROM\", to: \"$TO\") {
      contributionCalendar {
        totalContributions
        weeks { contributionDays { contributionCount date weekday } }
      }
    }
  }
}" 2>/dev/null) || {
    printf "\n  \033[38;2;255;215;0mError: could not reach GitHub\033[0m\n\n"
    read -rn1
    exit 1
}

TOTAL=$(printf '%s' "$DATA" | jq -r '.data.user.contributionsCollection.contributionCalendar.totalContributions')

printf '%s' "$DATA" | jq -r '
  .data.user.contributionsCollection.contributionCalendar.weeks |
  to_entries[] |
  .key as $w |
  .value.contributionDays[] |
  "\($w) \(.weekday) \(.contributionCount) \(.date[5:7] | tonumber)"
' | awk -v total="$TOTAL" -v year="$YEAR" '
BEGIN {
    G  = "\033[38;2;255;215;0m"
    DG = "\033[38;2;100;82;0m"
    R  = "\033[0m"
    B  = "\033[1m"
    Z  = "\033[38;2;38;28;0m"
    ch[0]="░"; ch[1]="░"; ch[2]="▒"; ch[3]="▓"; ch[4]="█"
    months[1]="Jan"; months[2]="Feb";  months[3]="Mar";  months[4]="Apr"
    months[5]="May"; months[6]="Jun";  months[7]="Jul";  months[8]="Aug"
    months[9]="Sep"; months[10]="Oct"; months[11]="Nov"; months[12]="Dec"
    num_weeks = 0
}
{
    w = $1+0; wd = $2+0; cnt = $3+0; m = $4+0
    grid[w,wd] = cnt
    week_month[w] = m
    if (w+1 > num_weeks) num_weeks = w+1
}
function cell(cnt) {
    if (cnt == 0) return Z ch[0] " " R
    if (cnt <= 3) return G ch[1] " " R
    if (cnt <= 6) return G ch[2] " " R
    if (cnt <= 9) return G ch[3] " " R
    return G ch[4] " " R
}
END {
    MARGIN = 5
    W = MARGIN + num_weeks * 2
    SEP = ""
    for (i = 0; i < W; i++) SEP = SEP "─"

    title = sprintf("lordziegler  ·  %d contributions  ·  %d", total+0, year+0)
    pad = int((W - length(title)) / 2)
    printf "\n"
    for (i = 0; i < pad; i++) printf " "
    printf "%s%s%s%s\n", G, B, title, R

    printf "\n%s%s%s\n", DG, SEP, R

    for (i = 0; i < W; i++) h[i] = " "
    prev_m = -1
    for (w = 0; w < num_weeks; w++) {
        m = week_month[w]
        if (m != prev_m) {
            pos = MARGIN + w*2
            nm = months[m]
            for (i = 1; i <= length(nm); i++) h[pos+i-1] = substr(nm, i, 1)
            prev_m = m
        }
    }
    printf "%s", DG
    for (i = 0; i < W; i++) printf "%s", h[i]
    printf "%s\n", R

    split("1 2 3 4 5 6 0", DO)
    for (r = 1; r <= 7; r++) {
        wd = DO[r]+0
        if      (wd == 1) printf "%sMon%s  ", DG, R
        else if (wd == 3) printf "%sWed%s  ", DG, R
        else if (wd == 5) printf "%sFri%s  ", DG, R
        else              printf "     "
        for (w = 0; w < num_weeks; w++) {
            cnt = ((w SUBSEP wd) in grid) ? grid[w,wd]+0 : 0
            printf "%s", cell(cnt)
        }
        printf "\n"
    }

    printf "%s%s%s\n", DG, SEP, R

    legend = "Less   ▫  ░  ▒  ▓  █   More"
    lpad = int((W - length(legend)) / 2)
    printf "\n"
    for (i = 0; i < lpad; i++) printf " "
    printf "%sLess%s   ", DG, R
    for (i = 0; i <= 4; i++) printf "%s%s%s  ", G, ch[i], R
    printf "%sMore%s\n\n", DG, R
}
'

read -rn1
