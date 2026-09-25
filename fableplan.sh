# fableplan — the latest Fable plans, the latest Opus executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves through --settings, which outranks the `env`
# block of user, project, and local settings and lasts for this invocation
# only. `claude` still resolves to whatever it names in your shell (function,
# alias, or binary), so a personal wrapper composes.
#
# The alias variables take full model names only, so each launch asks the
# installed Claude Code what `fable` and `opus` resolve to. A pin of either alias
# counts only when it names that family, so an OPUS pin that a parent fableplan
# pointed at Fable falls back to the latest Opus. `inherit` lets each subagent use its own model choice, or
# the current plan/execution model. The custom option adds an honestly labeled
# "Fable Plan" entry to the /model picker (the built-in entry says "Opus Plan").
fableplan() {
  local plan_model execution_model
  plan_model=$(_fableplan_resolve fable) || return
  execution_model=$(_fableplan_resolve opus) || return
  claude --model opusplan --permission-mode plan --settings '{
    "env": {
      "ANTHROPIC_DEFAULT_OPUS_MODEL": "'"$plan_model"'",
      "ANTHROPIC_DEFAULT_SONNET_MODEL": "'"$execution_model"'",
      "CLAUDE_CODE_SUBAGENT_MODEL": "inherit",
      "ANTHROPIC_CUSTOM_MODEL_OPTION": "opusplan",
      "ANTHROPIC_CUSTOM_MODEL_OPTION_NAME": "Fable Plan",
      "ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION": "'"$plan_model in plan mode, $execution_model otherwise"'"
    }
  }' "$@"
}

_fableplan_resolve() {
  local settings=${2:-'{}'} model
  model=$(_fableplan_probe "$1" "$settings") || return
  case $model in
    *"$1"*) printf '%s\n' "$model" ;;
    *) _fableplan_probe "$1" "$(printf '%s' "$settings" |
      jq -c --arg pin "ANTHROPIC_DEFAULT_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')_MODEL" '.env[$pin] = ""')" ;;
  esac
}

_fableplan_probe() {
  printf '%s\n' '{"type":"control_request","request_id":"fableplan","request":{"subtype":"get_settings"}}' |
    command claude -p --bare --model "$1" --no-session-persistence --settings "$2" \
      --input-format stream-json --output-format stream-json --verbose |
    jq -er --arg alias "$1" 'select(.response.request_id == "fableplan") | .response.response.applied.model | select(. != $alias)' ||
    { echo "fableplan: Claude Code did not resolve the \`$1\` model alias" >&2; return 1; }
}
