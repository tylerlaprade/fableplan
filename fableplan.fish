# fableplan — the latest Fable plans, the latest Opus executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves through --settings, which outranks the `env`
# block of user, project, and local settings and lasts for this invocation
# only. `claude` still resolves to whatever it names in your shell (function
# or binary), so a personal wrapper composes.
#
# The alias variables take full model names only, so each launch asks the
# installed Claude Code what `fable` and `opus` resolve to, ignoring any pins of
# those two aliases. `inherit` lets each subagent use its own model choice, or
# the current plan/execution model. The custom option adds an honestly labeled
# "Fable Plan" entry to the /model picker (the built-in entry says "Opus Plan").
function fableplan --description "Claude Code: the latest Fable plans, the latest Opus executes"
    set -l plan_model (_fableplan_resolve fable); or return
    set -l execution_model (_fableplan_resolve opus); or return
    claude --model opusplan --permission-mode plan --settings '{
      "env": {
        "ANTHROPIC_DEFAULT_OPUS_MODEL": "'$plan_model'",
        "ANTHROPIC_DEFAULT_SONNET_MODEL": "'$execution_model'",
        "CLAUDE_CODE_SUBAGENT_MODEL": "inherit",
        "ANTHROPIC_CUSTOM_MODEL_OPTION": "opusplan",
        "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "Fable Plan",
        "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "'"$plan_model in plan mode, $execution_model otherwise"'"
      }
    }' $argv
end

function _fableplan_resolve
    printf '%s\n' '{"type":"control_request","request_id":"fableplan","request":{"subtype":"get_settings"}}' |
        command claude -p --bare --model $argv[1] --no-session-persistence \
            --settings '{"env":{"ANTHROPIC_DEFAULT_OPUS_MODEL":"","ANTHROPIC_DEFAULT_FABLE_MODEL":""}}' \
            --input-format stream-json --output-format stream-json --verbose |
        jq -er --arg alias $argv[1] 'select(.response.request_id == "fableplan") | .response.response.applied.model | select(. != $alias)'
    or begin
        echo "fableplan: Claude Code did not resolve the `$argv[1]` model alias" >&2
        return 1
    end
end
