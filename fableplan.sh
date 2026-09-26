# fableplan — the latest Fable plans, the latest Opus executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves through --settings, which outranks the `env`
# block of user, project, and local settings and lasts for this invocation
# only. `claude` still resolves to whatever it names in your shell (function,
# alias, or binary), so a personal wrapper composes.
#
# The alias variables take full model names only, so each launch asks the
# installed Claude Code what `fable` and `opus` resolve to, in one process.
# A pin of either alias counts only when it names that family, so an OPUS pin
# that a parent fableplan pointed at Fable falls back to the latest Opus.
# `inherit` lets each subagent use its own model choice, or the current
# plan/execution model. The custom option adds an honestly labeled
# "Fable Plan" entry to the /model picker (the built-in entry says "Opus Plan").
#
# Claude Code keeps only the last --settings and --model, so a caller's own
# flags would silently drop the remap. fableplan takes them over instead: it
# merges every --settings into its own, keeps an older Fable or Opus with a
# warning, and refuses --model and any pin that breaks the Fable/Opus split.
fableplan() {
  command -v jq >/dev/null 2>&1 || { echo "fableplan: requires jq 1.7 or later" >&2; return 1; }
  local models plan_model execution_model settings user_settings='{}' arg value remaining=$#
  while [[ $remaining -gt 0 ]]; do
    arg=$1; shift; remaining=$((remaining - 1))
    case $arg in
      --model|--model=*) echo "fableplan: --model would replace opusplan and drop the Fable/Opus split; pin an older model with ANTHROPIC_DEFAULT_FABLE_MODEL or ANTHROPIC_DEFAULT_OPUS_MODEL, or run plain claude for one model" >&2; return 1 ;;
      --settings)
        [[ $remaining -gt 0 ]] || { echo "fableplan: $arg needs a value" >&2; return 1; }
        value=$1; shift; remaining=$((remaining - 1)) ;;
      --settings=*) value=${arg#*=} ;;
      --) set -- "$@" "$arg"; while [[ $remaining -gt 0 ]]; do set -- "$@" "$1"; shift; remaining=$((remaining - 1)); done; continue ;;
      *) set -- "$@" "$arg"; continue ;;
    esac
    user_settings=$(_fableplan_merge_settings "$user_settings" "$value") || return
  done
  jq -en --argjson user "$user_settings" '
    def pin($key; $family):
      $user.env[$key] // empty | tostring
      | select(ascii_downcase | contains($family | ascii_downcase) | not)
      | "fableplan: --settings sets \($key) to \(.), which is outside the \($family) family, so the remap would break\n" | halt_error(1);
    if $user.env.ANTHROPIC_DEFAULT_SONNET_MODEL then
      "fableplan: --settings sets ANTHROPIC_DEFAULT_SONNET_MODEL, but execution runs in the sonnet slot; pin an older Opus with ANTHROPIC_DEFAULT_OPUS_MODEL\n" | halt_error(1)
    else pin("ANTHROPIC_DEFAULT_FABLE_MODEL"; "Fable"), pin("ANTHROPIC_DEFAULT_OPUS_MODEL"; "Opus"), true end
  ' >/dev/null || return
  models=$(_fableplan_resolve "$user_settings") || return
  plan_model=${models% *} execution_model=${models#* }
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
  claude --model opusplan --permission-mode plan --settings "$settings" "$@"
}

_fableplan_merge_settings() {
  case $(printf '%s' "$2" | sed 's/^[[:space:]]*//') in
    '{'*) printf '%s' "$2" | jq -c --argjson merged "$1" '$merged * .' 2>/dev/null ||
      { echo "fableplan: --settings is not a valid JSON object" >&2; return 1; } ;;
    *) [[ -f $2 ]] || { echo "fableplan: settings file not found: $2" >&2; return 1; }
      jq -c --argjson merged "$1" '$merged * .' "$2" 2>/dev/null ||
      { echo "fableplan: $2 is not a valid JSON object" >&2; return 1; } ;;
  esac
}

_fableplan_resolve() {
  local probe_settings responses fable_shell opus_shell resolutions alias latest variable pin plan_model execution_model
  probe_settings=$(printf '%s' "$1" | jq -c '.env.ANTHROPIC_DEFAULT_FABLE_MODEL = "" | .env.ANTHROPIC_DEFAULT_OPUS_MODEL = ""')
  responses=$(_fableplan_probe "$probe_settings")
  fable_shell=$(printenv ANTHROPIC_DEFAULT_FABLE_MODEL)
  opus_shell=$(printenv ANTHROPIC_DEFAULT_OPUS_MODEL)
  resolutions=$(jq -r --argjson caller "$1" --arg fable "$fable_shell" --arg opus "$opus_shell" '
    {fable: $fable, opus: $opus} as $shell
    | .response.request_id as $alias
    | .response.response
    | select(.applied.model != $alias and (.applied.model | contains($alias)))
    | "ANTHROPIC_DEFAULT_\($alias | ascii_upcase)_MODEL" as $variable
    | [.sources[] | if .source == "flagSettings" then $caller else .settings end | .env[$variable] // empty | select(. != "")] as $pins
    | "\($alias) \(.applied.model) \($variable) \(($pins | last) // $shell[$alias])"' <<<"$responses")
  while read -r alias latest variable pin; do
    case ${pin%'[1m]'} in
      ''|"$latest") ;;
      *"$alias"*)
        echo "fableplan: using $pin from $variable instead of the latest $latest" >&2
        latest=$pin ;;
    esac
    case $alias in
      fable) plan_model=$latest ;;
      opus) execution_model=$latest ;;
    esac
  done <<EOF
$resolutions
EOF
  [[ -n $plan_model ]] || { echo "fableplan: Claude Code did not resolve the \`fable\` model alias" >&2; return 1; }
  [[ -n $execution_model ]] || { echo "fableplan: Claude Code did not resolve the \`opus\` model alias" >&2; return 1; }
  printf '%s %s\n' "$plan_model" "$execution_model"
}

_fableplan_probe() {
  local responses line
  responses=$(mktemp -d)/responses
  mkfifo "$responses"
  # shellcheck disable=SC2094,SC2312 # The FIFO carries replies back to the request loop, and an empty reply is the failure signal.
  {
    {
      printf '%s\n' \
        '{"type":"control_request","request_id":"fable","request":{"subtype":"get_settings"}}' \
        '{"type":"control_request","request_id":"switch","request":{"subtype":"set_model","model":"opus"}}'
      while IFS= read -r line; do
        case $line in
          *'"request_id":"switch"'*) printf '%s\n' '{"type":"control_request","request_id":"opus","request":{"subtype":"get_settings"}}' ;;
          *'"request_id":"fable"'*) printf '%s\n' "$line" >&4 ;;
          *'"request_id":"opus"'*) printf '%s\n' "$line" >&4; break ;;
        esac
      done <"$responses"
    } | command claude -p --bare --model fable --no-session-persistence --settings "$1" \
      --input-format stream-json --output-format stream-json --verbose >"$responses"
  } 4>&1
  rm -r "${responses%/*}"
}
