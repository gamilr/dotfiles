# Names the Herdr pane after the command it is running, the way tmux's
# automatic-rename named windows after the running process.
#
# Herdr has no equivalent setting: `label` is only ever set explicitly, by
# prefix+shift+o or `herdr pane rename`. It does infer the agent, cwd and
# terminal title on its own, but nothing for plain shell panes, so the rename
# has to come from the shell. Herdr injects HERDR_PANE_ID into every managed
# pane, which is what makes this addressable without asking the server which
# pane we are.
#
# Cost is deliberately near zero: both renames are fired into the background,
# which measured 0.5ms per command. Detecting a hand-typed name per command
# instead needs a synchronous read back from the server, and that measured
# 12.5ms per command, so the check runs once at start-up and `herdr-autoname
# off` covers renaming later.
#
# Sourced from ~/.zshrc; not executable, unlike nav.sh and send-key.sh.

[[ ${HERDR_ENV:-} == 1 && -n ${HERDR_PANE_ID:-} ]] || return 0
(( $+commands[herdr] )) || return 0

autoload -Uz add-zsh-hook

# Commands whose name says nothing about what the pane is doing. Renaming on
# these just makes the border flicker. herdr-autoname is here so that turning
# this off does not first relabel the pane after the command doing the turning
# off, which would then take the name you just typed down with it.
typeset -ga HERDR_AUTONAME_IGNORE=(cd ls ll la clear pwd echo exit z herdr-autoname)

# The label we last set. Empty means the pane should be showing none, which is
# how `off` knows whether a label is ours to clear or yours to leave alone.
typeset -g _herdr_autoname_last=''

# Reads .result.pane.label out of the single-line JSON with zsh parameter
# expansion. Deliberately not jq or python: a python start-up alone costs more
# than the ~11ms socket round trip it would be parsing.
_herdr_autoname_label() {
  local json=$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null)
  local rest=${json#*\"label\":\"}
  [[ $rest == $json ]] && return 0   # no label key: pane is unlabelled
  print -r -- ${rest%%\"*}
}

# One read, once per shell. A pane that already carries a name is yours, so
# never touch it.
typeset -g _herdr_autoname_enabled=1
[[ -z "$(_herdr_autoname_label)" ]] || _herdr_autoname_enabled=0

_herdr_autoname_preexec() {
  (( _herdr_autoname_enabled )) || return 0

  # First word of the command line, minus any leading VAR=value assignments,
  # reduced to a basename so /opt/homebrew/bin/foo shows as foo.
  local word
  for word in ${(z)1}; do
    [[ $word == *=* ]] && continue
    break
  done
  word=${word##*/}
  [[ -z $word ]] && return 0
  (( ${HERDR_AUTONAME_IGNORE[(Ie)$word]} )) && return 0

  _herdr_autoname_last=$word
  herdr pane rename "$HERDR_PANE_ID" "$word" >/dev/null 2>&1 &!
}

# Back to no label at the prompt, so an idle pane renders exactly as it does
# today and Herdr's own agent label is not competing with a stale command name.
# Clearing rather than parking the directory name here is also what keeps the
# opt-out durable: a pane we manage is empty at the prompt, so a later shell in
# the same pane starts enabled instead of mistaking our leftover for your name.
_herdr_autoname_precmd() {
  (( _herdr_autoname_enabled )) || return 0
  [[ -n $_herdr_autoname_last ]] || return 0
  _herdr_autoname_last=''
  herdr pane rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1 &!
}

add-zsh-hook preexec _herdr_autoname_preexec
add-zsh-hook precmd _herdr_autoname_precmd

# Run this before or after naming a pane by hand; either order works, because
# `off` only clears a label this script set.
herdr-autoname() {
  case ${1:-status} in
    on)
      _herdr_autoname_enabled=1
      _herdr_autoname_last=''
      print "herdr autoname: on ($HERDR_PANE_ID)"
      ;;
    off)
      _herdr_autoname_enabled=0
      if [[ -n $_herdr_autoname_last ]]; then
        _herdr_autoname_last=''
        herdr pane rename "$HERDR_PANE_ID" --clear >/dev/null 2>&1
      fi
      print "herdr autoname: off ($HERDR_PANE_ID)"
      ;;
    status)
      local state=off
      (( _herdr_autoname_enabled )) && state=on
      print "herdr autoname: $state ($HERDR_PANE_ID, label=${$(_herdr_autoname_label):-none})"
      ;;
    *)
      print "usage: herdr-autoname [on|off|status]" >&2
      return 2
      ;;
  esac
}
