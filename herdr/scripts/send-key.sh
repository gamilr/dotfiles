#!/usr/bin/env bash
# Send a key chord to the focused pane.
# tmux equivalent: bind a send-keys 'C-r'  (atuin history search)
set -u
key=${1:?key required}

# Herdr runs `type = "shell"` bindings detached from the server, so PATH is
# whatever the server inherited at launch. Pin the two binaries this needs.
# /opt/homebrew/bin is Apple Silicon brew, /usr/local/bin is Intel brew: a
# brew-installed herdr lands in one or the other and neither is guaranteed to
# be in the server's inherited PATH.
PATH="$HOME/.nix-profile/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
export PATH
herdr() { command "${HERDR_BIN_PATH:-herdr}" "$@"; }

pane=${HERDR_ACTIVE_PANE_ID:-}
if [ -z "$pane" ]; then
  pane=$(herdr pane current 2>/dev/null | jq -r '.result.pane.pane_id // empty')
fi
[ -n "$pane" ] || exit 0

herdr pane send-keys "$pane" "$key" >/dev/null 2>&1
