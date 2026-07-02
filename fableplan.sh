# fableplan — Fable 5 plans, Opus 4.8 executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves via the documented alias env vars, scoped to
# this single invocation (bash and zsh both restore prefix assignments after a
# function call) — plain `claude` sessions are unaffected. `claude` resolves to
# whatever it names in your shell (function, alias, or binary), so a personal
# wrapper still composes.
fableplan() {
  ANTHROPIC_DEFAULT_OPUS_MODEL="claude-fable-5" \
  ANTHROPIC_DEFAULT_SONNET_MODEL="claude-opus-4-8" \
    claude --model opusplan "$@"
}
