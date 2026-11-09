#!/usr/bin/env sh
# CPU % as a full status-bar segment with progress bar.
# Format: cpu ▓▓░░░░░░ 23%
# Bar color: green < 60%, yellow 60-85%, red > 85%.

case "$(uname)" in
  Darwin)
    load=$(sysctl -n vm.loadavg | awk '{print $2}')
    ncpu=$(sysctl -n hw.ncpu)
    ;;
  Linux)
    read -r load _ _ < /proc/loadavg
    ncpu=$(nproc 2>/dev/null || echo 1)
    ;;
  *)
    load=0; ncpu=1
    ;;
esac

val=$(awk -v l="$load" -v c="$ncpu" 'BEGIN { p=(l*100)/c; if(p>100) p=100; printf "%d", p }')

if   [ "$val" -ge 85 ]; then color="#e67e80"
elif [ "$val" -ge 60 ]; then color="#dbbc7f"
else                         color="#a7c080"
fi

bar=$("$(dirname "$0")/bar.sh" "$val")
printf '#[fg=#83c092]cpu #[fg=%s]%s#[fg=#d3c6aa] %d%%' "$color" "$bar" "$val"
