# fableplan — Fable 5.1 plans, Opus 5.5 executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves through --settings, which outranks the `env`
# block of user, project, and local settings and lasts for this invocation
# only. `claude` still resolves to whatever it names in your shell (function
# or binary), so a personal wrapper composes.
#
# The alias variables take full model names only — they reject the
# `fable`/`opus`/`best` aliases that track the latest release, so each one is
# pinned by hand. `inherit` lets each subagent use its own model choice, or the
# current plan/execution model. The custom option adds an honestly labeled
# "Fable Plan" entry to the /model picker (the built-in entry says "Opus Plan").
function fableplan --description "Claude Code: Fable 5.1 plans, Opus 5.5 executes"
    claude --model opusplan --permission-mode plan --settings '{
      "env": {
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-fable-5-1",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-opus-5-5",
        "CLAUDE_CODE_SUBAGENT_MODEL": "inherit",
        "ANTHROPIC_CUSTOM_MODEL_OPTION": "opusplan",
        "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "Fable Plan",
        "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "Fable 5.1 in plan mode, Opus 5.5 otherwise"
      }
    }' $argv
end
