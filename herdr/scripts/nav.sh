#!/usr/bin/env bash
# Vim-aware pane navigation for Herdr.
# Mirrors the vim-tmux-navigator trick in ~/.config/tmux/tmux.conf: if the
# focused pane is running vim/nvim, forward the chord so the editor moves
# between its own splits; otherwise move between Herdr panes.
#
# When nvim reaches the edge of its own splits, smart-splits.nvim hands off to
# Herdr itself (lua/smart-splits/mux/herdr.lua), so the two directions compose.
#
# usage: nav.sh <left|down|up|right> <key-to-forward>
set -u

dir=${1:?direction required}
key=${2:?key required}

# Herdr runs `type = "shell"` bindings detached from the server, so PATH is
# whatever the server inherited at launch. Pin the two binaries this needs.
# /opt/homebrew/bin is Apple Silicon brew, /usr/local/bin is Intel brew: a
# brew-installed herdr lands in one or the other and neither is guaranteed to
# be in the server's inherited PATH.
PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PATH
herdr() { command "${HERDR_BIN_PATH:-herdr}" "$@"; }

# Only HERDR_ACTIVE_PANE_ID is trusted here: a detached shell binding must not
# inherit a stale HERDR_PANE_ID. With no target Herdr resolves the UI-focused
# pane, which is what a keybinding wants.
pane=${HERDR_ACTIVE_PANE_ID:-}

if [ -n "$pane" ]; then
  info=$(herdr pane process-info --pane "$pane" 2>/dev/null) || exit 0
else
  info=$(herdr pane process-info 2>/dev/null) || exit 0
fi
[ -n "$info" ] || exit 0

# Same command set the tmux is_vim regex matches: vi/vim/nvim/view, optional
# g- prefix, optional x suffix, optional diff suffix.
read -r pane_id is_vim <<EOJ
$(printf '%s' "$info" | jq -r '
  .result.process_info as $p
  | [ ($p.pane_id // ""),
      ([$p.foreground_processes[]?.name // ""]
        | map(test("^g?(view|n?vim?x?)(diff)?$"))
        | any) ]
  | @tsv')
EOJ

[ -n "$pane_id" ] || exit 0

if [ "$is_vim" = "true" ]; then
  herdr pane send-keys "$pane_id" "$key" >/dev/null 2>&1
else
  herdr pane focus --direction "$dir" --pane "$pane_id" >/dev/null 2>&1
fi
