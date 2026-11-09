#!/bin/sh
# SessionStart hook: preload the herdr skill body into context when Claude
# runs inside a Herdr pane, so the first turn already carries it and it is
# cached from the first request instead of costing a Skill round-trip later.
set -eu
[ "${HERDR_ENV:-}" = "1" ] || exit 0
skill="$HOME/.claude/skills/herdr/SKILL.md"
[ -r "$skill" ] || exit 0
# Skip subagent sessions; they get their own context.
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if d.get("agent_id") else 1)' 2>/dev/null; then
    exit 0
  fi
else
  cat >/dev/null
fi
printf '%s\n\n' "The herdr skill is preloaded below. Do not invoke Skill(herdr); it would duplicate this text."
# Emit the body after the YAML frontmatter.
awk 'BEGIN{c=0} /^---$/ && c<2 {c++; next} c>=2' "$skill"
