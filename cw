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
#
#   cw --setup     one-time: stop cw-on/cw-off asking for your password
#   cw --unsetup   undo that

MIN_BATTERY="${CW_MIN_BATTERY:-10}"   # percent
STATE_DIR="${TMPDIR:-/tmp}/cw-$(id -u)"   # one file per running cw-on
SUDOERS_FILE="/etc/sudoers.d/cw"
PMSET="${CW_PMSET:-/usr/bin/pmset}"   # override only for testing

case "$0" in
  /*) SELF="$0" ;;
  *)  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" ;;
esac

battery_pct() {   # prints battery % if running on battery, nothing if plugged in
  b=$("$PMSET" -g batt)
  if echo "$b" | grep -q "Battery Power"; then
    echo "$b" | grep -o "[0-9]*%" | head -1 | tr -d "%"
  fi
}

# Change the sleep setting. Uses the passwordless rule from `cw --setup` if it
# exists; otherwise falls back to asking for the password (when interactive).
set_sleep_disabled() {   # $1 = 1 (stay awake) or 0 (normal)
  sudo -n "$PMSET" -a disablesleep "$1" 2>/dev/null && return 0
  if [ -t 0 ] && sudo "$PMSET" -a disablesleep "$1"; then return 0; fi
  echo "cw: couldn't change the sleep setting. Run 'cw --setup' once, then try again." >&2
  return 1
}

passwordless() { sudo -n "$PMSET" -a disablesleep 1 >/dev/null 2>&1 || return 1; }

# ---- guard: runs in the background as you; keeps sleep off while cw-on lives ----
guard() {
  id="$1"; watch="$2"
  mkdir -p "$STATE_DIR"
  echo "$$" > "$STATE_DIR/$id"
  cleanup() {
    rm -f "$STATE_DIR/$id"
    # Only turn sleep back on when no other cw-on session is still running.
    [ "$(live_sessions)" -eq 0 ] && sudo -n "$PMSET" -a disablesleep 0
  }
  trap cleanup EXIT
  trap 'exit' TERM HUP
  n=0
  while [ -f "$STATE_DIR/$id" ] && kill -0 "$watch" 2>/dev/null; do
    if [ $((n % 15)) -eq 0 ]; then              # battery check every ~30s
      pct=$(battery_pct)
      if [ -n "$pct" ] && [ "$pct" -lt "$MIN_BATTERY" ]; then
        rm -rf "$STATE_DIR"                     # end every session
        sudo -n "$PMSET" -a disablesleep 0
        osascript -e "display notification \"Battery at ${pct}% - stay-awake turned OFF\" with title \"cw\"" 2>/dev/null
        exit
      fi
    fi
    n=$((n + 1))
    sleep 2
  done
}

live_sessions() {   # how many cw-on guards are actually still running
  n=0
  for f in "$STATE_DIR"/*; do
    [ -f "$f" ] && kill -0 "$(cat "$f" 2>/dev/null)" 2>/dev/null && n=$((n + 1))
  done
  echo "$n"
}

status() {
  if "$PMSET" -g | grep -q 'SleepDisabled[[:space:]]*1'; then
    if [ "$(live_sessions)" -gt 0 ]; then
      echo "cw: ON  (Mac will stay awake, even with the lid closed)"
    else
      echo "cw: ON, but no cw-on session is running (left over)."
      echo "    Run cw-off to restore normal sleep."
    fi
  else
    echo "cw: OFF (normal sleep)"
  fi
}

setup() {
  need_mac
  user="$(id -un)"
  tmp="$(mktemp)"
  printf '# Added by cw: lets %s turn sleep on/off without a password.\n%s ALL=(root) NOPASSWD: %s -a disablesleep 0, %s -a disablesleep 1\n' \
    "$user" "$user" /usr/bin/pmset /usr/bin/pmset > "$tmp"
  /usr/sbin/visudo -cf "$tmp" >/dev/null || { rm -f "$tmp"; echo "Setup failed (bad sudoers rule)."; exit 1; }
  echo "cw: your Mac password is needed one last time."
  sudo install -m 440 -o root -g wheel "$tmp" "$SUDOERS_FILE" && rm -f "$tmp" \
    && echo "Done. cw-on and cw-off won't ask for your password anymore."
}

unsetup() {
  sudo rm -f "$SUDOERS_FILE" && echo "Removed. cw-on and cw-off will ask for your password again."
}

need_mac() {
  [ "$(uname)" = "Darwin" ] || { echo "cw only works on macOS."; exit 1; }
}

turn_off() {
  need_mac
  rm -rf "$STATE_DIR"
  set_sleep_disabled 0
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

  if ! passwordless; then
    echo "cw: one-time setup so cw never asks for your password again."
    setup || exit 1
    passwordless || { echo "Couldn't turn stay-awake on."; exit 1; }
  fi
  "$SELF" __guard "session-$$" "$$" >/dev/null 2>&1 &
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
  # Don't rely only on the background guard: stop it and restore sleep here too
  # (unless another cw-on session is still running).
  rm -f "$STATE_DIR/session-$$"
  sleep 3
  [ "$(live_sessions)" -eq 0 ] && set_sleep_disabled 0
  status
}

# ---- dispatch ----
if [ "$1" = "__guard" ]; then
  guard "$2" "$3"; exit
fi

case "$(basename "$0")" in
  cw-on)  turn_on "$@" ;;
  cw-off) turn_off ;;
  *)
    case "$1" in
      -h|--help) sed -n '2,13p' "$SELF" | sed 's/^# \{0,1\}//' ;;
      --setup)   setup ;;
      --unsetup) unsetup ;;
      *) need_mac; status ;;
    esac ;;
esac
