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
    printf "\n  \033[38;2;212;168;67mError: could not reach GitHub\033[0m\n\n"
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
    bg[0] = "\033[48;2;42;34;24m"
    bg[1] = "\033[48;2;107;74;21m"
    bg[2] = "\033[48;2;168;112;32m"
    bg[3] = "\033[48;2;212;168;67m"
    bg[4] = "\033[48;2;255;215;0m"
    R = "\033[0m"
    B = "\033[1m"
    A = "\033[38;2;212;168;67m"
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
END {
    printf "\n  %s%d contributions in %d%s\n\n", B, total+0, year+0, R

    # Month header
    W = 5 + num_weeks * 2
    for (i = 0; i < W; i++) h[i] = " "
    prev_m = -1
    for (w = 0; w < num_weeks; w++) {
        m = week_month[w]
        if (m != prev_m) {
            pos = 5 + w*2
            nm = months[m]
            for (i = 1; i <= length(nm); i++) h[pos+i-1] = substr(nm, i, 1)
            prev_m = m
        }
    }
    printf "%s", A
    for (i = 0; i < W; i++) printf "%s", h[i]
    printf "%s\n", R

    # Grid rows: Mon Tue Wed Thu Fri Sat Sun (weekday 0=Sun 1=Mon...6=Sat)
    split("1 2 3 4 5 6 0", DO)
    for (r = 1; r <= 7; r++) {
        wd = DO[r]+0
        if      (wd == 1) printf "%s Mon %s", A, R
        else if (wd == 3) printf "%s Wed %s", A, R
        else if (wd == 5) printf "%s Fri %s", A, R
        else              printf "     "
        for (w = 0; w < num_weeks; w++) {
            cnt = ((w SUBSEP wd) in grid) ? grid[w,wd]+0 : 0
            if      (cnt == 0) printf "%s  %s", bg[0], R
            else if (cnt <= 3) printf "%s  %s", bg[1], R
            else if (cnt <= 6) printf "%s  %s", bg[2], R
            else if (cnt <= 9) printf "%s  %s", bg[3], R
            else               printf "%s  %s", bg[4], R
        }
        printf "\n"
    }

    printf "\n  %sLess%s", A, R
    for (i = 0; i <= 4; i++) printf "  %s  %s", bg[i], R
    printf "  %sMore%s\n", A, R
}
'

printf "\n  \033[38;2;212;168;67mPress any key to close\033[0m\n"
read -rn1
