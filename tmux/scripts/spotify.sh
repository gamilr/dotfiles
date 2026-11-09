#!/usr/bin/env sh
# Now-playing segment for tmux status bar.
# Emits a self-contained colored segment when music is playing; emits nothing
# when paused/stopped so the bar collapses naturally.
#
# macOS: queries the th-ch/youtube-music desktop app's API Server plugin
#        (http://localhost:26538) using a Bearer token saved at
#        ~/.config/tmux/yt_music_token. Falls back to Apple Music via AppleScript.
# Linux: playerctl.

MAX_LEN=60   # max characters per field before per-field truncation
TOKEN_FILE="$HOME/.config/tmux/yt_music_token"
API="http://localhost:26538/api/v1/song"

title=""
album=""
artist=""

case "$(uname)" in
  Darwin)
    if [ -r "$TOKEN_FILE" ]; then
      token=$(cat "$TOKEN_FILE")
      json=$(curl -s --max-time 1 -H "Authorization: Bearer $token" "$API" 2>/dev/null)
      if [ -n "$json" ] && [ "$json" != "Unauthorized" ]; then
        # Skip when paused (isPaused == true) — emit nothing.
        paused=$(printf '%s' "$json" | jq -r '.isPaused // empty' 2>/dev/null)
        if [ "$paused" != "true" ]; then
          title=$(printf  '%s' "$json" | jq -r '.title  // empty' 2>/dev/null)
          album=$(printf  '%s' "$json" | jq -r '.album  // empty' 2>/dev/null)
          artist=$(printf '%s' "$json" | jq -r '.artist // empty' 2>/dev/null)
        fi
      fi
    fi

    # Apple Music fallback
    if [ -z "$title" ] && [ -z "$artist" ]; then
      fallback=$(osascript -e '
        if application "Music" is running then
          tell application "Music"
            if player state is playing then
              return (name of current track) & "|" & (album of current track) & "|" & (artist of current track)
            end if
          end tell
        end if
      ' 2>/dev/null)
      if [ -n "$fallback" ]; then
        title=$(printf  '%s' "$fallback" | cut -d'|' -f1)
        album=$(printf  '%s' "$fallback" | cut -d'|' -f2)
        artist=$(printf '%s' "$fallback" | cut -d'|' -f3)
      fi
    fi
    ;;
  Linux)
    if command -v playerctl >/dev/null 2>&1; then
      status=$(playerctl status 2>/dev/null)
      if [ "$status" = "Playing" ]; then
        title=$(playerctl  metadata --format '{{title}}'  2>/dev/null)
        album=$(playerctl  metadata --format '{{album}}'  2>/dev/null)
        artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)
      fi
    fi
    ;;
esac

# Nothing playing → emit nothing (tmux collapses the slot).
[ -z "$title" ] && [ -z "$artist" ] && exit 0

# Per-field truncate (with ellipsis) to keep the bar compact.
trunc() {
  s="$1"
  if [ "${#s}" -gt "$MAX_LEN" ]; then
    printf '%s…' "$(printf '%s' "$s" | cut -c1-$((MAX_LEN - 1)))"
  else
    printf '%s' "$s"
  fi
}
title=$(trunc  "$title")
album=$(trunc  "$album")
artist=$(trunc "$artist")

# Build "Title │ Album │ Artist", skipping empty fields.
sep="#[fg=#475258] - #[fg=#d699b6]"
out="$title"
[ -n "$album" ]  && out="${out:+$out$sep}$album"
[ -n "$artist" ] && out="${out:+$out$sep}$artist"

# Emit a self-contained segment: purple text, trailing pipe separator.
printf '#[fg=#d699b6] ♪ %s #[fg=#475258]│' "$out"
