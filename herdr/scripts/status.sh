#!/usr/bin/env sh
# Metric segments for Herdr's tab-bar status area (ui.tab_bar_right).
#
#   cpu ##......  23%      ram ####....  51%      bat ########  80%+
#   (rendered with block bars; see the glyph table below)
#
# Same metrics, thresholds and bar renderer as the tmux status bar in
# ~/.config/tmux/scripts/{cpu,ram,battery,bar}.sh, minus the color: Herdr
# documents no ANSI support for command entries, only their last line of
# output, so the bar carries the signal on its own.
#
# usage: status.sh <cpu|ram|bat>
#
# Wired up in ~/.config/herdr/config.toml under [ui] tab_bar_right. Herdr runs
# these through `/bin/sh -lc` on the server, so a remote session reports the
# remote machine. Output must be a single line: Herdr keeps the last one and
# clears the entry on failure, empty output, or timeout.
#
# Source is deliberately ASCII-only: the block glyphs are printf octal escapes
# so the file survives transports that mangle UTF-8.

metric=${1:-}

G_FULL=$(printf '\342\226\223')   # U+2593 dark shade  (filled bar cell)
G_EMPTY=$(printf '\342\226\221')  # U+2591 light shade (empty bar cell)

# Bar cells. Herdr drops the whole status area when the tab row is too narrow
# for it, so shrink this before dropping a segment.
BAR_WIDTH=${HERDR_STATUS_BAR_WIDTH:-8}

# Herdr's `sh -lc` inherits the server's PATH, which is whatever launched it.
PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/sbin:/usr/bin:/bin:$PATH"
export PATH

# Block-progress bar for 0-100, same rounding as tmux bar.sh.
bar() {
  v=$1; w=${2:-$BAR_WIDTH}
  [ "$v" -lt 0 ] && v=0
  [ "$v" -gt 100 ] && v=100
  f=$(( (v * w + 50) / 100 )); e=$(( w - f ))
  out=""
  i=0; while [ "$i" -lt "$f" ]; do out="$out$G_FULL";  i=$((i + 1)); done
  i=0; while [ "$i" -lt "$e" ]; do out="$out$G_EMPTY"; i=$((i + 1)); done
  printf '%s' "$out"
}

cpu_value() {
  case "$(uname)" in
    Darwin)
      load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}')
      ncpu=$(sysctl -n hw.ncpu 2>/dev/null)
      ;;
    Linux)
      read -r load _ _ < /proc/loadavg
      ncpu=$(nproc 2>/dev/null || echo 1)
      ;;
    *) load=0; ncpu=1 ;;
  esac
  awk -v l="${load:-0}" -v c="${ncpu:-1}" 'BEGIN { p=(l*100)/c; if(p>100) p=100; printf "%d", p }'
}

ram_value() {
  case "$(uname)" in
    Darwin)
      vm_stat 2>/dev/null | awk '
        /Pages free/                   { gsub(/\./,"",$3); free=$3 }
        /Pages active/                 { gsub(/\./,"",$3); active=$3 }
        /Pages inactive/               { gsub(/\./,"",$3); inactive=$3 }
        /Pages speculative/            { gsub(/\./,"",$3); spec=$3 }
        /Pages wired down/             { gsub(/\./,"",$4); wired=$4 }
        /Pages occupied by compressor/ { gsub(/\./,"",$5); comp=$5 }
        END {
          used  = active + wired + comp
          total = used + free + inactive + spec
          if (total > 0) printf "%d", used*100/total; else printf "0"
        }'
      ;;
    Linux)
      awk '
        /^MemTotal:/     { t=$2 }
        /^MemAvailable:/ { a=$2 }
        END { if (t>0) printf "%d", (t-a)*100/t; else printf "0" }
      ' /proc/meminfo
      ;;
    *) printf '0' ;;
  esac
}

# Percentage plus '+' while on AC, or nothing at all on a desktop.
bat_value() {
  case "$(uname)" in
    Darwin)
      info=$(pmset -g batt 2>/dev/null)
      p=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
      [ -z "$p" ] && return 0
      if printf '%s' "$info" | grep -q 'AC Power'; then s='+'; else s=''; fi
      printf '%s %s' "$p" "$s"
      ;;
    Linux)
      for b in /sys/class/power_supply/BAT0 /sys/class/power_supply/BAT1; do
        [ -f "$b/capacity" ] || continue
        p=$(cat "$b/capacity")
        if [ "$(cat "$b/status" 2>/dev/null)" = "Charging" ]; then s='+'; else s=''; fi
        printf '%s %s' "$p" "$s"
        return 0
      done
      ;;
  esac
}

case "$metric" in
  cpu)
    v=$(cpu_value)
    printf 'cpu %s %d%%\n' "$(bar "$v")" "$v"
    ;;
  ram)
    v=$(ram_value)
    printf 'ram %s %d%%\n' "$(bar "$v")" "$v"
    ;;
  bat)
    raw=$(bat_value)
    # No battery: print nothing so Herdr hides the entry instead of showing 0%.
    [ -n "$raw" ] || exit 0
    p=$(printf '%s' "$raw" | awk '{print $1}')
    s=$(printf '%s' "$raw" | awk '{print $2}')
    printf 'bat %s %d%%%s\n' "$(bar "$p")" "$p" "$s"
    ;;
  *)
    echo "usage: status.sh <cpu|ram|bat>" >&2
    exit 2
    ;;
esac
