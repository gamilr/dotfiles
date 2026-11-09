#!/usr/bin/env sh
# Online indicator: "online" (green) when default route exists, "offline" (red) when not.
# Text label variant (works without a Nerd Font).
case "$(uname)" in
  Darwin)
    if route -n get default >/dev/null 2>&1; then
      printf '#[fg=#a7c080]online'
    else
      printf '#[fg=#e67e80]offline'
    fi
    ;;
  Linux)
    if ip route show default 2>/dev/null | grep -q .; then
      printf '#[fg=#a7c080]online'
    else
      printf '#[fg=#e67e80]offline'
    fi
    ;;
  *)
    printf '#[fg=#7a8478]?'
    ;;
esac
