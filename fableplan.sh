# fableplan — Fable 5.1 plans, Opus 5 executes.
# Mechanism and caveats: see README.md in this directory.
#
# The directory is resolved when this file is sourced. bash has BASH_SOURCE;
# zsh sets neither BASH_SOURCE nor $0 when sourcing, so its prompt-expansion
# form is used there, hidden in an eval so bash never parses it.
if [ -n "${ZSH_VERSION:-}" ]; then
  eval 'FABLEPLAN_DIR=${${(%):-%N}:A:h}'
else
  FABLEPLAN_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
fi

# The subshell keeps BUN_OPTIONS scoped to this single invocation in every
# POSIX shell. Subshells inherit function definitions, so `claude` still
# resolves to whatever it names in your shell (function, alias, or binary)
# and a personal wrapper composes.
fableplan() {
  (
    # Loads fableplan.js into the claude binary before its bundle runs. An
    # existing BUN_OPTIONS value is kept.
    export BUN_OPTIONS="${BUN_OPTIONS:+$BUN_OPTIONS }--preload $FABLEPLAN_DIR/fableplan.js"
    # Adds the Fable Plan picker row and the hook that records the permission
    # mode; --model selects the row for this session.
    claude --settings "$FABLEPLAN_DIR/fableplan.settings.json" \
      --model fableplan --permission-mode plan "$@"
  )
}
