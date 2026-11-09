#!/usr/bin/env sh
# Claude Code status line.
#
#   model Opus 5 xhigh | ctx 34% | dir dotfiles | branch main*^2 | skills caveman:ultra,herdr | mcp claude-docs | usage 5h 24% 2h14m 7d 41% 3d2h $1.23
#
# Machine metrics deliberately live only in Herdr's tab bar
# (ui.tab_bar_right -> ~/.config/herdr/scripts/status.sh) and the tmux status
# bar: those are global, so repeating cpu/ram/battery per Claude pane just
# duplicates them. What is left here is the per-pane context Herdr cannot know.
#
# Wired up via "statusLine" in claude/settings.json. Claude Code feeds it a JSON
# blob on stdin (model, workspace dirs, cost, ...) and renders every line of
# stdout as its own row under the prompt. A row is clipped at the terminal
# edge, never wrapped, so the script wraps the segments itself (see the end).
#
# Source is deliberately ASCII-only: every non-ASCII glyph is built with printf
# octal escapes so the file survives transports that mangle UTF-8.

input=$(cat)

# --- Glyphs ------------------------------------------------------------------
G_PIPE=$(printf '\342\224\202')   # U+2502 box drawing vertical
G_UP=$(printf '\342\206\221')     # U+2191 up arrow    (commits ahead)
G_DOWN=$(printf '\342\206\223')   # U+2193 down arrow  (commits behind)
G_ELLIPSIS=$(printf '\342\200\246') # U+2026 ellipsis  (name truncated)

# --- Palette (everforest, matches tmux + nvim) -------------------------------
E=$(printf '\033')
DIM="$E[38;2;71;82;88m"        # bg3     #475258
YELLOW="$E[38;2;219;188;127m"  # yellow  #dbbc7f
AQUA="$E[38;2;131;192;146m"    # aqua    #83c092
BLUE="$E[38;2;127;187;179m"    # blue    #7fbbb3
GREEN="$E[38;2;167;192;128m"   # green   #a7c080
PURPLE="$E[38;2;214;153;182m"  # purple  #d699b6
RED="$E[38;2;230;126;128m"     # red     #e67e80
BOLD="$E[1m"
RESET="$E[0m"
SEP="$DIM$G_PIPE$RESET"

# --- Tiny TTL cache, so a big repo's git status does not stall the prompt -----
cache_dir="${TMPDIR:-/tmp}/claude-statusline-$(id -u 2>/dev/null || echo 0)"
mkdir -p "$cache_dir" 2>/dev/null

age() { # age <path>  -> seconds since mtime, or a huge number when absent
  [ -e "$1" ] || { echo 999999; return; }
  # GNU first: on coreutils `stat -f` means filesystem info and succeeds with
  # garbage, so the BSD form must be the fallback, not the first attempt.
  m=$(stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0)
  echo $(( $(date +%s) - m ))
}

cached() { # cached <key> <ttl-seconds> <command...>
  key=$1; ttl=$2; shift 2
  f="$cache_dir/$key"
  [ "$(age "$f")" -lt "$ttl" ] && { cat "$f"; return 0; }
  "$@" > "$f.$$" 2>/dev/null
  mv "$f.$$" "$f" 2>/dev/null
  cat "$f" 2>/dev/null
}

# Same cache, but a stale or missing entry is refreshed in the background and
# whatever is on disk (possibly nothing) is returned now. For commands that
# take seconds: the prompt must never wait on them. The lock dir makes the
# refresh single-flight across the many renders Claude Code fires per turn; a
# lock older than two minutes belongs to a dead refresh and is discarded.
cached_bg() { # cached_bg <key> <ttl-seconds> <command...>
  key=$1; ttl=$2; shift 2
  f="$cache_dir/$key"
  if [ "$(age "$f")" -ge "$ttl" ]; then
    [ "$(age "$f.lock")" -ge 120 ] && rm -rf "$f.lock" 2>/dev/null
    if mkdir "$f.lock" 2>/dev/null; then
      # stdin/stdout/stderr all detached, otherwise Claude Code's read of this
      # script's stdout blocks until the child exits.
      ( "$@" > "$f.$$" 2>/dev/null </dev/null && mv "$f.$$" "$f"; rm -rf "$f.lock" ) >/dev/null 2>&1 &
    fi
  fi
  cat "$f" 2>/dev/null
}

# --- Claude context from stdin JSON ------------------------------------------
model=""; effort=""; dir=""; cost=""; sid=""; transcript=""
ctx=""; five_pct=""; five_at=""; week_pct=""; week_at=""; spend_pct=""; spend_at=""
if command -v jq >/dev/null 2>&1; then
  model=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // empty' 2>/dev/null)
  # Live reasoning effort (low/medium/high/xhigh/max), tracking /effort changes
  # mid-session. Absent when the model has no effort parameter.
  effort=$(printf '%s' "$input" | jq -r '.effort.level // empty' 2>/dev/null)
  dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)
  cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
  transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
  # Context window: input-side tokens of the last API response over the model's
  # window. null before the first response and right after /compact.
  ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)
  # Subscription rate limits, same numbers as /usage. Present only for claude.ai
  # Pro/Max (or behind a gateway spend limit) and only after the first response;
  # each window can be absent on its own and is dropped once its reset passes.
  five_pct=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
  five_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
  week_pct=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
  week_at=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty' 2>/dev/null)
  spend_pct=$(printf '%s' "$input" | jq -r '.rate_limits.spend_limit.used_percentage // empty' 2>/dev/null)
  spend_at=$(printf '%s' "$input" | jq -r '.rate_limits.spend_limit.resets_at // empty' 2>/dev/null)
fi
[ -z "$dir" ] && dir=$PWD

# --- git: <branch>[*][^N][vM], same logic as tmux scripts/git.sh -------------
git_raw() {
  cd "$1" 2>/dev/null || return 0
  b=$(git symbolic-ref --short HEAD 2>/dev/null) \
    || b=$(git rev-parse --short HEAD 2>/dev/null) \
    || return 0
  [ -z "$b" ] && return 0
  d=""; [ -n "$(git status --porcelain 2>/dev/null)" ] && d="*"
  a=""; bh=""
  counts=$(git rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null)
  if [ -n "$counts" ]; then
    behind=$(printf '%s' "$counts" | awk '{print $1}')
    ahead=$(printf '%s' "$counts" | awk '{print $2}')
    [ "$ahead" -gt 0 ] 2>/dev/null && a="$G_UP$ahead"
    [ "$behind" -gt 0 ] 2>/dev/null && bh="$G_DOWN$behind"
  fi
  # Branch and decorations are tab-separated so the renderer can compare the
  # bare branch name against the directory basename.
  printf '%s\t%s%s%s' "$b" "$d" "$a" "$bh"
}

dir_key=$(printf '%s' "$dir" | cksum | awk '{print $1}')
git_seg=$(cached "git-$dir_key" 5 git_raw "$dir")

# --- Skills and MCP servers ---------------------------------------------------
# Neither is in the stdin blob, so both come from what the session leaves on
# disk. Skills: every Skill tool call and every skill the user invoked as a
# slash command, read from this session's transcript. A typed skill and a
# typed local command (/login, /clear, /model, ...) both leave a user record
# with <command-name>; Claude Code 2.1 writes <command-message> BEFORE
# <command-name> for skills and prompts (bundled and on-disk alike) and after
# it for local commands, and that order is the only thing telling them apart,
# so it is the filter. MCP: what `claude mcp list` reports as
# connected (a health check, ~2s, so it runs in the background and the prompt
# reads the cache) plus every server whose tools this session already called
# (the transcript again; that is what catches the Chrome extension and the IDE
# bridge, which `claude mcp list` does not list). Names are folded to
# lowercase-dashed with the "claude.ai " prefix dropped so both sources agree.
session_raw() { # session_raw <transcript>  -> "S <skill>" and "M <mcp tool>" lines
  jq -r '
    if .type == "assistant" then
      (.message.content[]? | select(.type == "tool_use")
        | if .name == "Skill" then "S " + (.input.skill // empty) + "\t" + (.input.args // "")
          elif (.name | startswith("mcp__")) then "M " + .name
          else empty end)
    elif .type == "user" then
      (.message.content
        | if type == "string" then . else ([.[]? | select(.type == "text") | .text] | join("\n")) end
        | select((indices("<command-message>") | .[0]) as $m | (indices("<command-name>") | .[0]) as $n
                 | $m != null and $n != null and $m < $n)
        | ((capture("<command-args>(?<a>[^<]*)</command-args>") | .a) // "") as $args
        | capture("<command-name>/(?<n>[^<]+)</command-name>"; "g") | "S " + .n + "\t" + $args)
    else empty end' "$1" 2>/dev/null
}

mcp_list_raw() { # connected server names, one per line, from the workspace dir
  command -v claude >/dev/null 2>&1 || return 0
  cd "$dir" 2>/dev/null
  claude mcp list 2>/dev/null | grep -E 'Connected[[:space:]]*$' | sed 's/: .*//'
}

mcp_name() { # mcp_name  (stdin -> stdout): fold names from both sources to one spelling
  tr 'A-Z' 'a-z' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^claude-ai-//; s/^-//; s/-$//'
}

skills=""; mcp=""
if [ -n "$sid" ] && [ -f "$transcript" ]; then
  sess=$(cached_bg "sess-$sid" 10 session_raw "$transcript")
  # One entry per skill, in first-use order, carrying the args of its latest
  # invocation when those are a single word (a mode such as "ultra"); a
  # sentence of args is a task description, not a state, and is left out.
  # Plugin skills arrive as plugin:skill; the skill name alone is enough.
  skills=$(printf '%s\n' "$sess" | sed -n 's/^S //p' | awk -F'\t' '
    { n = $1; sub(/^.*:/, "", n); if (n == "") next
      if (!(n in args)) order[++k] = n
      args[n] = $2 }
    END { for (i = 1; i <= k; i++) { n = order[i]; a = args[n]
            if (a != "" && length(a) <= 16 && a !~ /[[:space:]]/) n = n ":" a
            print n } }' | paste -sd, -)
  used=$(printf '%s\n' "$sess" | sed -n 's/^M mcp__//p' | sed 's/__[A-Za-z0-9-][A-Za-z0-9_-]*$//' | mcp_name)
else
  used=""
fi
# The caveman plugin keeps its live mode in a flag file, keyed on the session
# id, and it changes on plain-text "stop caveman" as well as on the slash
# command, so that flag overrides whatever the transcript said: it sets
# caveman:<mode>, adds the entry when the mode came from a hook rather than a
# typed command, and removes it on "off". Same reading rules as the plugin's
# own caveman-statusline.sh: no symlinks, 64 bytes, [a-z0-9-] only, an empty
# flag means full.
caveman_mode() { # caveman_mode  -> mode word, "off", or nothing when the plugin left no state
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  flag="$cfg/.caveman-sessions/$sid.mode"
  { [ -n "$sid" ] && [ -f "$flag" ]; } || flag="$cfg/.caveman-active"
  [ -L "$flag" ] && return 0
  [ -f "$flag" ] || return 0
  m=$(head -c 64 "$flag" 2>/dev/null | tr -d '\n\r' | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9-')
  case "$m" in
    '') echo full ;;
    off|lite|full|ultra|wenyan-lite|wenyan|wenyan-full|wenyan-ultra|commit|review|compress) echo "$m" ;;
  esac
}
cm=$(caveman_mode)
if [ -n "$cm" ]; then
  rest=$(printf '%s\n' "$skills" | tr ',' '\n' | grep -v '^caveman\(:.*\)*$' | paste -sd, -)
  if [ "$cm" = off ]; then
    skills=$rest
  else
    skills="caveman:$cm${rest:+,$rest}"
  fi
fi

connected=$(cached_bg "mcp-$dir_key" 300 mcp_list_raw | mcp_name)
mcp=$(printf '%s\n%s\n' "$connected" "$used" | awk 'NF && !seen[$0]++' | paste -sd, -)

# --- Trim over-long names so the line stays readable in a narrow terminal ----
# Branch gets the wider budget: worktree branches carry a ticket id plus a full
# description, and cutting them hides the part that tells two branches apart.
DIR_MAX=${CLAUDE_STATUSLINE_DIR_MAX:-40}
BRANCH_MAX=${CLAUDE_STATUSLINE_BRANCH_MAX:-80}
SKILLS_MAX=${CLAUDE_STATUSLINE_SKILLS_MAX:-40}
MCP_MAX=${CLAUDE_STATUSLINE_MCP_MAX:-60}

trim() { # trim <string> <max>
  s=$1; m=$2
  if [ "${#s}" -gt "$m" ]; then
    printf '%s%s' "$(printf '%s' "$s" | cut -c1-$((m - 1)))" "$G_ELLIPSIS"
  else
    printf '%s' "$s"
  fi
}

# --- Usage helpers ------------------------------------------------------------
# Percentage colour: calm below 50, yellow to 80, red above. Same bands for the
# context window and the rate limits so one glance reads the same everywhere.
pct_color() { # pct_color <number>  -> escape sequence
  awk -v p="$1" -v g="$GREEN" -v y="$YELLOW" -v r="$RED" \
    'BEGIN { if (p+0 >= 80) printf "%s", r; else if (p+0 >= 50) printf "%s", y; else printf "%s", g }'
}

pct_int() { # pct_int <number>  -> rounded whole number
  awk -v p="$1" 'BEGIN { printf "%d", p + 0.5 }'
}

until_reset() { # until_reset <epoch>  -> "2h14m" / "3d2h" / "9m" / "" when past or empty
  [ -n "$1" ] || return 0
  awk -v t="$1" -v now="$(date +%s)" 'BEGIN {
    s = t - now; if (s <= 0) exit
    d = int(s / 86400); h = int((s % 86400) / 3600); m = int((s % 3600) / 60)
    if (d > 0) printf "%dd%dh", d, h
    else if (h > 0) printf "%dh%02dm", h, m
    else printf "%dm", (m > 0 ? m : 1) }'
}

limit_part() { # limit_part <window> <pct> <resets_at>  -> "5h 24% 2h14m" coloured, or nothing
  [ -n "$2" ] || return 0
  r=$(until_reset "$3")
  printf '%s%s %s%s%%%s%s' "$DIM" "$1" "$(pct_color "$2")" "$(pct_int "$2")" "$RESET" "${r:+ $DIM$r$RESET}"
}

# --- Render -------------------------------------------------------------------
TAB=$(printf '\t')
branch=${git_seg%%$TAB*}
deco=${git_seg#*$TAB}
[ "$deco" = "$git_seg" ] && deco=""

segs=""            # one segment per line; joined into rows at the end
add() { # add <text>
  segs="$segs$1
"
}

[ -n "$model" ] && add "${DIM}model $BLUE$model$RESET${effort:+ $PURPLE$effort$RESET}"
[ -n "$ctx" ] && add "${DIM}ctx $(pct_color "$ctx")$(pct_int "$ctx")%$RESET"

# The dir segment is dropped when it just repeats the branch (git worktrees are
# routinely named after their branch), so the line does not say it twice.
base=$(basename "$dir")
[ "$base" = "$branch" ] || add "${DIM}dir $YELLOW$BOLD$(trim "$base" "$DIR_MAX")$RESET"
[ -n "$branch" ] && add "${DIM}branch $AQUA$(trim "$branch" "$BRANCH_MAX")$deco$RESET"

[ -n "$skills" ] && add "${DIM}skills $PURPLE$(trim "$skills" "$SKILLS_MAX")$RESET"
[ -n "$mcp" ] && add "${DIM}mcp $GREEN$(trim "$mcp" "$MCP_MAX")$RESET"

# One "usage" segment: rate-limit windows in /usage order (session 5h, week
# 7d, gateway spend), then the session cost. Only parts present are shown.
usage=""
for w in "5h $five_pct $five_at" "7d $week_pct $week_at" "spend $spend_pct $spend_at"; do
  set -- $w
  part=$(limit_part "$1" "$2" "$3")
  [ -n "$part" ] && usage="${usage:+$usage }$part"
done
if [ -n "$cost" ]; then
  cs=$(awk -v c="$cost" 'BEGIN { if (c+0 >= 0.005) printf "$%.2f", c }')
  [ -n "$cs" ] && usage="${usage:+$usage }$DIM$cs$RESET"
fi
[ -n "$usage" ] && add "${DIM}usage $usage"

# --- Wrap to the terminal width ------------------------------------------------
# Claude Code clips each row at the terminal edge instead of wrapping, so the
# segments are packed into rows here: a segment that would cross the edge
# starts a new row. COLUMNS is set by Claude Code before every run (the script's
# stdout is a pipe, so tput cannot see the terminal). Without it, or with
# CLAUDE_STATUSLINE_WRAP=0, everything goes on one row as before.
vlen() { # vlen <text>  -> visible width: escapes stripped, characters counted
  printf '%s' "$1" | LC_ALL=C sed "s/$E\[[0-9;]*m//g" \
    | LC_ALL=${LANG:-en_US.UTF-8} wc -m 2>/dev/null | tr -d ' '
}

cols=${COLUMNS:-0}
[ "${CLAUDE_STATUSLINE_WRAP:-1}" = 1 ] && [ "$cols" -gt 0 ] 2>/dev/null || cols=999999
printf '%s' "$segs" | {
  row=""; w=0
  while IFS= read -r seg; do
    [ -n "$seg" ] || continue
    sw=$(vlen "$seg")
    if [ -z "$row" ]; then
      row=$seg; w=$sw
    elif [ $((w + 3 + sw)) -le "$cols" ]; then   # 3 = " | " around the separator glyph
      row="$row $SEP $seg"; w=$((w + 3 + sw))
    else
      printf '%s\n' "$row"
      row=$seg; w=$sw
    fi
  done
  [ -n "$row" ] && printf '%s\n' "$row"
}
