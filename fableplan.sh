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
#
# Claude Code keeps only the last --settings and --model, so a caller's own
# flags would silently drop the remap. fableplan takes them over instead: it
# merges every --settings into its own, keeps an older Fable or Opus with a
# warning, and refuses any model choice that breaks the Fable/Opus split.
fableplan() {
  command -v jq >/dev/null 2>&1 || { echo "fableplan: requires jq 1.7 or later" >&2; return 1; }
  local plan_model execution_model settings user_settings='{}' model=opusplan arg value remaining=$#
  while [ "$remaining" -gt 0 ]; do
    arg=$1; shift; remaining=$((remaining - 1))
    case $arg in
      --settings|--model)
        [ "$remaining" -gt 0 ] || { echo "fableplan: $arg needs a value" >&2; return 1; }
        value=$1; shift; remaining=$((remaining - 1)) ;;
      --settings=*|--model=*) value=${arg#*=}; arg=${arg%%=*} ;;
      --) set -- "$@" "$arg"; while [ "$remaining" -gt 0 ]; do set -- "$@" "$1"; shift; remaining=$((remaining - 1)); done; continue ;;
      *) set -- "$@" "$arg"; continue ;;
    esac
    case $arg in
      --settings) user_settings=$(_fableplan_merge_settings "$user_settings" "$value") || return ;;
      --model)
        case $(printf '%s' "$value" | tr '[:upper:]' '[:lower:]') in
          opusplan|'opusplan[1m]') model=$value ;;
          *) echo "fableplan: --model $value would replace opusplan and drop the Fable/Opus split; run plain claude for one model" >&2; return 1 ;;
        esac ;;
    esac
  done
  jq -en --argjson user "$user_settings" '
    def pin($key; $family; $role):
      $user.env[$key] // empty | tostring
      | if ascii_downcase | contains($family | ascii_downcase) then
          "fableplan: \($role) on \(.) from --settings\n" | stderr | empty
        else
          "fableplan: --settings sets \($key) to \(.), which is outside the \($family) family, so the remap would break\n" | halt_error(1)
        end;
    if $user.env.ANTHROPIC_DEFAULT_SONNET_MODEL then
      "fableplan: --settings sets ANTHROPIC_DEFAULT_SONNET_MODEL, but execution runs in the sonnet slot; pin an older Opus with ANTHROPIC_DEFAULT_OPUS_MODEL\n" | halt_error(1)
    else pin("ANTHROPIC_DEFAULT_FABLE_MODEL"; "Fable"; "planning"), pin("ANTHROPIC_DEFAULT_OPUS_MODEL"; "Opus"; "executing"), true end
  ' >/dev/null || return
  plan_model=$(_fableplan_resolve fable "$user_settings") || return
  execution_model=$(_fableplan_resolve opus "$user_settings") || return
  settings=$(jq -cn --argjson user "$user_settings" --arg plan "$plan_model" --arg execution "$execution_model" '
    ($user.env // {}) as $user_env
    | $user + {env: (
        {CLAUDE_CODE_SUBAGENT_MODEL: "inherit"}
        + (if $user_env | keys | any(startswith("ANTHROPIC_CUSTOM_MODEL_OPTION")) then {} else {
            ANTHROPIC_CUSTOM_MODEL_OPTION: "opusplan",
            ANTHROPIC_CUSTOM_MODEL_OPTION_NAME: "Fable Plan",
            ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION: "\($plan) in plan mode, \($execution) otherwise"
          } end)
        + $user_env
        + {ANTHROPIC_DEFAULT_OPUS_MODEL: $plan, ANTHROPIC_DEFAULT_SONNET_MODEL: $execution})}
  ') || return
  claude --model "$model" --permission-mode plan --settings "$settings" "$@"
}

_fableplan_merge_settings() {
  case $(printf '%s' "$2" | sed 's/^[[:space:]]*//') in
    '{'*) printf '%s' "$2" | jq -c --argjson merged "$1" '$merged * .' 2>/dev/null ||
      { echo "fableplan: --settings is not a valid JSON object" >&2; return 1; } ;;
    *) [ -f "$2" ] || { echo "fableplan: settings file not found: $2" >&2; return 1; }
      jq -c --argjson merged "$1" '$merged * .' "$2" 2>/dev/null ||
      { echo "fableplan: $2 is not a valid JSON object" >&2; return 1; } ;;
  esac
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
