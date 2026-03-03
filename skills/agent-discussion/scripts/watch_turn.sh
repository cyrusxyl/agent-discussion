#!/usr/bin/env bash
# watch_turn.sh — Block until it's this agent's turn or the discussion ends.
#
# Usage:
#   bash watch_turn.sh <file> <agent-name>
#
# Exit codes:
#   0  — it's your turn  ([TURN: <agent-name>] is the last turn marker)
#   1  — discussion over ([AGREED:…] or [DEADLOCKED] found)
#   2  — bad arguments

FILE="$1"
MY_NAME="$2"

if [[ -z "$FILE" || -z "$MY_NAME" ]]; then
  echo "Usage: watch_turn.sh <file> <agent-name>" >&2
  exit 2
fi

# Returns: "our_turn" | "agreed" | "deadlocked" | "waiting"
check_state() {
  local tail_out
  tail_out=$(tail -n 25 "$FILE" 2>/dev/null)

  if echo "$tail_out" | grep -qE '^\[AGREED:'; then
    echo "agreed"; return
  fi
  if echo "$tail_out" | grep -qE '^\[DEADLOCKED\]'; then
    echo "deadlocked"; return
  fi

  local last_turn
  last_turn=$(echo "$tail_out" | grep -oE '\[TURN: [^]]+\]' | tail -1)
  if [[ "$last_turn" == "[TURN: $MY_NAME]" ]]; then
    echo "our_turn"; return
  fi

  echo "waiting"
}

# Check immediately before blocking (handles the case where it's already our turn)
state=$(check_state)
case "$state" in
  our_turn)   exit 0 ;;
  agreed|deadlocked) exit 1 ;;
esac

# Get initial mtime for stat-based fallback
get_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}
last_mtime=$(get_mtime "$FILE")

while true; do
  # Prefer inotifywait (Linux inotify-tools) — event-driven, zero CPU
  if command -v inotifywait &>/dev/null; then
    inotifywait -q -e modify,close_write "$FILE" 2>/dev/null
  else
    # Fallback: poll mtime every 3 seconds
    while true; do
      sleep 3
      new_mtime=$(get_mtime "$FILE")
      if [[ "$new_mtime" != "$last_mtime" ]]; then
        last_mtime="$new_mtime"
        break
      fi
    done
  fi

  state=$(check_state)
  case "$state" in
    our_turn)          exit 0 ;;
    agreed|deadlocked) exit 1 ;;
  esac
  # still waiting — loop back and watch again
done
