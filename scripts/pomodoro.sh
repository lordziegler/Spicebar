#!/bin/bash
# Pomodoro timer for waybar — timestamp state, no daemon
# on-click: toggle  |  on-click-right: reset  |  on-click-middle: skip

STATE=/tmp/.pomodoro
WORK=1500    # 25 min
SHORT=300    # 5 min
LONG=900     # 15 min
SIG=9        # waybar custom module signal offset (SIGRTMIN+9)

COFFEE="<span font='Symbols Nerd Font 14'></span>"
BARLEY="<span font='Symbols Nerd Font 14'>󰁳</span>"

_read() {
    if [[ -f "$STATE" ]]; then
        read -r phase start duration paused_at done < "$STATE"
        done=${done:-0}
    else
        phase=idle start=0 duration=0 paused_at=0 done=0
    fi
}

_write() { printf '%s %s %s %s %s\n' "$phase" "$start" "$duration" "$paused_at" "$done" > "$STATE"; }

_signal() {
    local n=$(( $(kill -l SIGRTMIN) + SIG ))
    pkill -"$n" waybar 2>/dev/null || true
}

_remaining() {
    local now; now=$(date +%s)
    if (( paused_at > 0 )); then
        echo $(( duration - (paused_at - start) ))
    else
        echo $(( duration - (now - start) ))
    fi
}

_notify() { notify-send -u normal -t 5000 "Pomodoro" "$1" 2>/dev/null || true; }

case "${1:-status}" in

    toggle)
        _read; now=$(date +%s)
        if [[ "$phase" == "idle" ]]; then
            phase=work start=$now duration=$WORK paused_at=0
        elif (( paused_at > 0 )); then
            elapsed=$(( paused_at - start ))
            start=$(( now - elapsed )); paused_at=0
        else
            paused_at=$now
        fi
        _write; _signal
        ;;

    reset)
        rm -f "$STATE"; _signal
        ;;

    skip)
        _read; now=$(date +%s)
        if [[ "$phase" == "work" ]]; then
            (( done++ ))
            if (( done >= 4 )); then
                phase=longbreak duration=$LONG done=0
            else
                phase=break duration=$SHORT
            fi
        else
            phase=work duration=$WORK
        fi
        start=$now paused_at=0
        _write; _signal
        ;;

    status|*)
        _read; now=$(date +%s)
        if [[ "$phase" == "idle" ]]; then
            printf '{"text":" ","class":"idle","tooltip":"\u25b6 Start Pomodoro"}\n'
            exit 0
        fi
        rem=$(_remaining)
        if (( rem <= 0 )); then
            if [[ "$phase" == "work" ]]; then
                (( done++ ))
                if (( done >= 4 )); then
                    _notify "Long break · 15 min"
                    phase=longbreak duration=$LONG done=0
                else
                    _notify "Short break · 5 min"
                    phase=break duration=$SHORT
                fi
            else
                _notify "Work time! Session $(( done + 1 )) of 4"
                phase=work duration=$WORK
            fi
            start=$now paused_at=0
            _write; rem=$duration
        fi
        m=$(( rem / 60 )); s=$(( rem % 60 ))
        t=$(printf "%02d:%02d" "$m" "$s")
        case "$phase" in
            work)      icon="$BARLEY"; cls="work";      tip="Session $(( done + 1 )) of 4" ;;
            break)     icon="$COFFEE"; cls="break";     tip="Short break" ;;
            longbreak) icon="$COFFEE"; cls="longbreak"; tip="Long break" ;;
        esac
        (( paused_at > 0 )) && cls="${cls}-paused"
        printf '{"text":"%s %s","class":"%s","tooltip":"%s"}\n' "$icon" "$t" "$cls" "$tip"
        ;;
esac
