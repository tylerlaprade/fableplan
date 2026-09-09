#!/bin/sh
# fableplan — records the permission mode for fableplan.js.
#
# Claude Code runs this on UserPromptSubmit, PreToolUse and PostToolUse with
# the hook input on stdin and CLAUDE_PID, the pid of the claude process, in
# the environment. The mode lands in a directory only this user can enter,
# written to a unique temporary name and renamed into place, so a predictable
# name in a shared /tmp can neither be pre-planted as a symlink nor be read
# half-written.
set -u

dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/fableplan-$(id -u)"
if [ ! -d "$dir" ]; then
  mkdir -m 700 "$dir" || exit 1
fi
if [ -L "$dir" ] || [ ! -O "$dir" ]; then
  printf 'fableplan: refusing to use %s: not a directory owned by you\n' "$dir" >&2
  exit 1
fi
chmod 700 "$dir"

mode=$(jq -r '.permission_mode // empty') || exit 1
tmp="$dir/claude-mode.${CLAUDE_PID:?}.$$"
printf '%s\n' "$mode" > "$tmp" && mv -f "$tmp" "$dir/claude-mode.$CLAUDE_PID"
