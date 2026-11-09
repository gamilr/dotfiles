#!/usr/bin/env sh
# Print git status segment for tmux status bar:
#   <branch>[*][↑N][↓M]
#     *  = working tree dirty (staged or unstaged changes, or untracked files)
#     ↑N = N commits ahead of upstream
#     ↓M = M commits behind upstream
# In detached HEAD, branch is the short SHA.
# Usage:  git.sh <path>
#   Pass the pane's current path via tmux:  #(git.sh "#{pane_current_path}")

cd "${1:-$PWD}" 2>/dev/null || exit 0

branch=$(git symbolic-ref --short HEAD 2>/dev/null) \
  || branch=$(git rev-parse --short HEAD 2>/dev/null) \
  || exit 0

[ -z "$branch" ] && exit 0

# Dirty marker: any porcelain output means uncommitted changes / untracked files.
dirty=""
[ -n "$(git status --porcelain 2>/dev/null)" ] && dirty="*"

# Ahead/behind vs upstream (silent if no upstream tracked).
ahead=""
behind=""
counts=$(git rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
if [ -n "$counts" ]; then
  b=$(printf '%s' "$counts" | awk '{print $1}')
  a=$(printf '%s' "$counts" | awk '{print $2}')
  [ "$a" -gt 0 ] 2>/dev/null && ahead="↑$a"
  [ "$b" -gt 0 ] 2>/dev/null && behind="↓$b"
fi

printf '%s%s%s%s' "$branch" "$dirty" "$ahead" "$behind"
