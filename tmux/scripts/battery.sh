#!/usr/bin/env sh
# Battery % as a full status-bar segment with progress bar.
# Format: bat ▓▓▓▓▓▓▓░ 80%+
# Bar color (inverted: low = bad): green > 60%, yellow 30-60%, red < 30%.
# Trailing '+' shown when charging.

pct=""
suffix=""

case "$(uname)" in
  Darwin)
    info=$(pmset -g batt 2>/dev/null)
    pct=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
    [ -z "$pct" ] && exit 0
    printf '%s' "$info" | grep -q 'AC Power' && suffix='+'
    ;;
  Linux)
    for bat in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
      if [ -f "$bat/capacity" ]; then
        pct=$(cat "$bat/capacity")
        status=$(cat "$bat/status" 2>/dev/null)
        [ "$status" = "Charging" ] && suffix='+'
        break
      fi
    done
    [ -z "$pct" ] && exit 0
    ;;
  *)
    exit 0
    ;;
esac

if   [ "$pct" -lt 30 ]; then color="#e67e80"
elif [ "$pct" -lt 60 ]; then color="#dbbc7f"
else                         color="#a7c080"
fi

bar=$("$(dirname "$0")/bar.sh" "$pct")
printf '#[fg=#dbbc7f]bat #[fg=%s]%s#[fg=#d3c6aa] %d%%%s' "$color" "$bar" "$pct" "$suffix"
