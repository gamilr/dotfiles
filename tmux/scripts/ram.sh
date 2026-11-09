#!/usr/bin/env sh
# RAM % used as a full status-bar segment with progress bar.
# Format: ram ▓▓▓▓░░░░ 51%
# Bar color: green < 60%, yellow 60-85%, red > 85%.

case "$(uname)" in
  Darwin)
    val=$(vm_stat | awk '
      /Pages free/                   { gsub(/\./,"",$3); free=$3 }
      /Pages active/                 { gsub(/\./,"",$3); active=$3 }
      /Pages inactive/               { gsub(/\./,"",$3); inactive=$3 }
      /Pages speculative/            { gsub(/\./,"",$3); spec=$3 }
      /Pages wired down/             { gsub(/\./,"",$4); wired=$4 }
      /Pages occupied by compressor/ { gsub(/\./,"",$5); comp=$5 }
      END {
        used  = active + wired + comp
        total = used + free + inactive + spec
        if (total > 0) printf "%d", used*100/total
        else printf "0"
      }')
    ;;
  Linux)
    val=$(awk '
      /^MemTotal:/     { t=$2 }
      /^MemAvailable:/ { a=$2 }
      END { if (t>0) printf "%d", (t-a)*100/t; else printf "0" }
    ' /proc/meminfo)
    ;;
  *)
    val=0
    ;;
esac

if   [ "$val" -ge 85 ]; then color="#e67e80"
elif [ "$val" -ge 60 ]; then color="#dbbc7f"
else                         color="#a7c080"
fi

bar=$("$(dirname "$0")/bar.sh" "$val")
printf '#[fg=#d699b6]ram #[fg=%s]%s#[fg=#d3c6aa] %d%%' "$color" "$bar" "$val"
