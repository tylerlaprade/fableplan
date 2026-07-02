# fableplan — Fable 5 plans, Opus 4.8 executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# set -lx makes each var function-local and exported: it reaches `claude`
# (including a wrapper function) and vanishes when fableplan returns —
# fish's native equivalent of the subshell in fableplan.sh.
function fableplan --description "Claude Code: Fable 5 plans, Opus 4.8 executes"
    set -lx ANTHROPIC_DEFAULT_OPUS_MODEL claude-fable-5
    set -lx ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-4-8
    # Adds an honestly-labeled "Fable Plan" entry to the /model picker
    # (the built-in entry for this mode says "Opus Plan").
    set -lx ANTHROPIC_CUSTOM_MODEL_OPTION opusplan
    set -lx ANTHROPIC_CUSTOM_MODEL_OPTION_NAME "Fable Plan"
    set -lx ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION "Fable 5 in plan mode, Opus 4.8 otherwise"
    claude --model opusplan $argv
end
