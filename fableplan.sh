# fableplan — Fable 5 plans, Opus 5 executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves via the documented alias env vars. The
# subshell keeps the exports scoped to this single invocation in every POSIX
# shell (bash, zsh, dash, and bash-as-sh, where a plain `VAR=x func` prefix
# assignment would leak into the calling shell). Subshells inherit function
# definitions, so `claude` still resolves to whatever it names in your shell
# (function, alias, or binary) and a personal wrapper composes.
fableplan() {
  (
    # Full model names only — these vars reject the `fable`/`opus`/`best`
    # aliases that track the latest release, so each one is pinned by hand.
    export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-fable-5"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-opus-5"
    # Adds an honestly-labeled "Fable Plan" entry to the /model picker
    # (the built-in entry for this mode says "Opus Plan").
    export ANTHROPIC_CUSTOM_MODEL_OPTION="opusplan"
    export ANTHROPIC_CUSTOM_MODEL_OPTION_NAME="Fable Plan"
    export ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION="Fable 5 in plan mode, Opus 5 otherwise"
    claude --model opusplan "$@"
  )
}
