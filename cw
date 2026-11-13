#!/bin/bash
# cw — keep your Mac awake (even with the lid closed) while Claude Code works.
#
#   cw        show whether stay-awake is ON or OFF
#   cw-on     turn stay-awake ON and start Claude Code
#             (extra args are passed to claude, e.g. `cw-on --resume`)
#   cw-off    turn stay-awake OFF (normal sleep)
#
# Works plugged in or on battery. Stay-awake turns OFF automatically when you
# quit Claude, close the Terminal window, or the battery drops below 10%.

MIN_BATTERY="${CW_MIN_BATTERY:-10}"   # percent
STATE_DIR="/var/run/cw"               # one file per running cw-on (root-owned)

case "$0" in
  /*) SELF="$0" ;;
  *)  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" ;;
esac

battery_pct() {   # prints battery % if running on battery, nothing if plugged in
  b=$(pmset -g batt)
  if echo "$b" | grep -q "Battery Power"; then
    echo "$b" | grep -o "[0-9]*%" | head -1 | tr -d "%"
  fi
}

# ---- guard: runs as root; keeps sleep disabled while its cw-on session lives ----
guard() {
  id="$1"; watch="$2"
  mkdir -p "$STATE_DIR"
  echo "$$" > "$STATE_DIR/$id"
  pmset -a disablesleep 1          # -a = both on battery and plugged in
  cleanup() {
    rm -f "$STATE_DIR/$id"
    # Only turn sleep back on when no other cw-on session is still running.
    if [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
      pmset -a disablesleep 0
    fi
  }
  trap cleanup EXIT
  trap 'exit' INT TERM HUP
  n=0
  while [ -f "$STATE_DIR/$id" ] && kill -0 "$watch" 2>/dev/null; do
    if [ $((n % 15)) -eq 0 ]; then              # battery check every ~30s
      pct=$(battery_pct)
      if [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ]; then
        rm -rf "$STATE_DIR"                     # end every session
        pmset -a disablesleep 0
        osascript -e "display notification \"Battery at ${pct}% - stay-awake turned OFF\" with title \"cw\"" 2>/dev/null
        exit
      fi
    fi
    n=$((n + 1))
    sleep 2
  done
}

status() {
  if pmset -g | grep -q 'SleepDisabled[[:space:]]*1'; then
    echo "cw: ON  (Mac will stay awake, even with the lid closed)"
  else
    echo "cw: OFF (normal sleep)"
  fi
}

need_mac() {
  [ "$(uname)" = "Darwin" ] || { echo "cw only works on macOS."; exit 1; }
}

turn_off() {
  need_mac
  sudo rm -rf "$STATE_DIR"
  sudo pmset -a disablesleep 0
  status
}

turn_on() {
  need_mac
  if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code isn't installed (the 'claude' command wasn't found)."
    echo "Install it with:  curl -fsSL https://claude.ai/install.sh | bash"
    echo "then open a new Terminal window and run cw-on again."
    exit 1
  fi
  pct=$(battery_pct)
  if [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ]; then
    echo "Battery is at ${pct}%. Plug in first (cw-on needs at least ${MIN_BATTERY}%)."
    exit 1
  fi

  echo "cw: your Mac password is needed to change sleep settings."
  sudo -v || { echo "Cancelled."; exit 1; }
  sudo "$SELF" __guard "session-$$" "$$" >/dev/null 2>&1 &
  sleep 1
  status
  echo "You can close the lid now. Don't put the Mac in a bag while it's on."
  echo

  while true; do
    printf "Type 'claude' or 'c' to start Claude Code (q to quit): "
    read -r choice || choice=q
    case "$choice" in
      claude) claude "$@"; break ;;
      c)      claude --dangerously-skip-permissions "$@"; break ;;
      q|quit|exit) break ;;
      *) echo "Not recognised: '$choice'" ;;
    esac
  done

  echo
  echo "Claude exited — turning stay-awake off..."
}

# ---- dispatch ----
if [ "$1" = "__guard" ]; then
  [ "$(id -u)" -eq 0 ] || exit 1
  guard "$2" "$3"; exit
fi

case "$(basename "$0")" in
  cw-on)  turn_on "$@" ;;
  cw-off) turn_off ;;
  *)
    case "$1" in
      -h|--help) sed -n '2,10p' "$SELF" | sed 's/^# \{0,1\}//' ;;
      *) need_mac; status ;;
    esac ;;
esac
