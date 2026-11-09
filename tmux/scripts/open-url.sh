#!/usr/bin/env sh
# Open the first URL from stdin in the platform's default browser.

url=$(grep -oE 'https?://[^[:space:]]+' | head -1)
[ -z "$url" ] && exit 0

case "$(uname)" in
  Darwin)
    open "$url" >/dev/null 2>&1 &
    ;;
  Linux)
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$url" >/dev/null 2>&1 &
    fi
    ;;
esac
