#!/bin/bash
# cw — run Claude Code and keep your Mac awake, even with the lid closed.
#
#   cw            start Claude Code with the Mac kept awake
#                 (extra args are passed to claude, e.g. `cw --resume`)
#   cw-on         keep the Mac awake without starting Claude (until cw-off)
#   cw-off        turn normal sleep back on (also an emergency reset)
#   cw --status   show whether the Mac is being kept awake
#
# Normal sleep comes back automatically when Claude exits, the Terminal window
# closes, or the battery drops below MIN_BATTERY percent while unplugged.

MIN_BATTERY="${CW_MIN_BATTERY:-20}"   # percent; override with CW_MIN_BATTERY=30
STATE_DIR="/var/run/cw"               # one file per active session (root-owned)

case "$0" in
  /*) SELF="$0" ;;
  *)  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" ;;
esac

# ---------- guard: runs as root, keeps sleep off while its session lives ----------
guard() {
  id="$1"; watch="$2"
  mkdir -p "$STATE_DIR"
  echo "$$" > "$STATE_DIR/$id"
  pmset -a disablesleep 1
  cleanup() {
    rm -f "$STATE_DIR/$id"
    # Only restore sleep when no other cw session is still running.
    if [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]; then
      pmset -a disablesleep 0
    fi
  }
  trap cleanup EXIT
  trap 'exit' INT TERM HUP
  while [ -f "$STATE_DIR/$id" ]; do
    if [ "$watch" != "manual" ] && ! kill -0 "$watch" 2>/dev/null; then
      break
    fi
    batt=$(pmset -g batt)
    if echo "$batt" | grep -q "Battery Power"; then
      pct=$(echo "$batt" | grep -o "[0-9]*%" | head -1 | tr -d "%")
      if [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ]; then
        rm -rf "$STATE_DIR"          # stop every session
        pmset -a disablesleep 0
        osascript -e "display notification \"Battery at ${pct}% - normal sleep restored\" with title \"cw\"" 2>/dev/null
        exit
      fi
    fi
    sleep 15
  done
}

status() {
  if pmset -g | grep -q 'SleepDisabled[[:space:]]*1'; then
    echo "Stay-awake: ON (Mac will NOT sleep, even with the lid closed)"
  else
    echo "Stay-awake: OFF (normal sleep)"
  fi
}

need_mac() {
  [ "$(uname)" = "Darwin" ] || { echo "cw only works on macOS."; exit 1; }
}

need_sudo() {
  echo "cw: your Mac password is needed to change sleep settings."
  sudo -v || { echo "Cancelled."; exit 1; }
}

turn_off() {
  need_mac
  sudo rm -rf "$STATE_DIR"
  sudo pmset -a disablesleep 0 && echo "Normal sleep restored."
}

turn_on() {
  need_mac
  need_sudo
  sudo nohup "$SELF" __guard manual manual >/dev/null 2>&1 &
  disown 2>/dev/null
  sleep 1
  status
  echo "The Mac stays awake until you run: cw-off"
}

start() {
  need_mac
  if ! command -v claude >/dev/null 2>&1; then
    echo "Claude Code isn't installed (the 'claude' command wasn't found)."
    echo "Install it with:  curl -fsSL https://claude.ai/install.sh | bash"
    echo "then open a new Terminal window and run cw again."
    exit 1
  fi
  need_sudo
  sudo "$SELF" __guard "session-$$" "$$" >/dev/null 2>&1 &
  sleep 1
  status
  echo "You can close the lid now. Plug in for long tasks, and don't put it in a bag."
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
  echo "Claude exited — restoring normal sleep..."
  sleep 2
  status
}

usage() { sed -n '2,12p' "$SELF" | sed 's/^# \{0,1\}//'; }

# ---------- dispatch ----------
if [ "$1" = "__guard" ]; then
  [ "$(id -u)" -eq 0 ] || exit 1
  guard "$2" "$3"; exit
fi

case "$(basename "$0")" in
  cw-on)  turn_on;  exit ;;
  cw-off) turn_off; exit ;;
esac

case "$1" in
  --on)        turn_on ;;
  --off)       turn_off ;;
  --status)    status ;;
  -h|--help)   usage ;;
  *)           start "$@" ;;
esac
