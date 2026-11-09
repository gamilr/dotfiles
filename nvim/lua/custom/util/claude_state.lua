-- Module-level state for the Claude tmux pane id.
-- Kept in its own module so multiple keymap closures share the same value
-- across reloads of claudecode.lua.
return { pane = nil }
