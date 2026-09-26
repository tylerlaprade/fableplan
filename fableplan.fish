# fableplan — the latest Fable plans, the latest Opus executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# Re-points opusplan's two halves through --settings, which outranks the `env`
# block of user, project, and local settings and lasts for this invocation
# only. `claude` still resolves to whatever it names in your shell (function
# or binary), so a personal wrapper composes.
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
function fableplan --description "Claude Code: the latest Fable plans, the latest Opus executes"
    if not command -q jq
        echo "fableplan: requires jq 1.7 or later" >&2
        return 1
    end
    set -l passthrough
    set -l user_settings '{}'
    set -l i 1
    while test $i -le (count $argv)
        set -l arg $argv[$i]
        set -l value
        switch $arg
            case --model '--model=*'
                echo "fableplan: --model would replace opusplan and drop the Fable/Opus split; pin an older model with ANTHROPIC_DEFAULT_FABLE_MODEL or ANTHROPIC_DEFAULT_OPUS_MODEL, or run plain claude for one model" >&2
                return 1
            case --settings
                set i (math $i + 1)
                if test $i -gt (count $argv)
                    echo "fableplan: $arg needs a value" >&2
                    return 1
                end
                set value $argv[$i]
            case '--settings=*'
                set value (string split -m 1 = -- $arg)[2]
            case --
                set -a passthrough $argv[$i..-1]
                break
            case '*'
                set -a passthrough $arg
                set i (math $i + 1)
                continue
        end
        set user_settings (_fableplan_merge_settings $user_settings $value); or return
        set i (math $i + 1)
    end
    jq -en --argjson user $user_settings '
      def pin($key; $family):
        $user.env[$key] // empty | tostring
        | select(ascii_downcase | contains($family | ascii_downcase) | not)
        | "fableplan: --settings sets \($key) to \(.), which is outside the \($family) family, so the remap would break\n" | halt_error(1);
      if $user.env.ANTHROPIC_DEFAULT_SONNET_MODEL then
        "fableplan: --settings sets ANTHROPIC_DEFAULT_SONNET_MODEL, but execution runs in the sonnet slot; pin an older Opus with ANTHROPIC_DEFAULT_OPUS_MODEL\n" | halt_error(1)
      else pin("ANTHROPIC_DEFAULT_FABLE_MODEL"; "Fable"), pin("ANTHROPIC_DEFAULT_OPUS_MODEL"; "Opus"), true end
    ' >/dev/null; or return
    set -l models (_fableplan_resolve $user_settings); or return
    set -l plan_model $models[1]
    set -l execution_model $models[2]
    set -l settings (jq -cn --argjson user $user_settings --arg plan $plan_model --arg execution $execution_model '
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
    '); or return
    claude --model opusplan --permission-mode plan --settings $settings $passthrough
end

function _fableplan_merge_settings
    if string match -qr '^\s*\{' -- $argv[2]
        printf '%s' $argv[2] | jq -c --argjson merged $argv[1] '$merged * .' 2>/dev/null
        or begin
            echo "fableplan: --settings is not a valid JSON object" >&2
            return 1
        end
    else
        if not test -f $argv[2]
            echo "fableplan: settings file not found: $argv[2]" >&2
            return 1
        end
        jq -c --argjson merged $argv[1] '$merged * .' $argv[2] 2>/dev/null
        or begin
            echo "fableplan: $argv[2] is not a valid JSON object" >&2
            return 1
        end
    end
end

function _fableplan_resolve
    set -l definition (path resolve (functions --details _fableplan_resolve))
    command bash -c 'source "$1"; _fableplan_resolve "$2"' bash (path dirname $definition)/fableplan.sh $argv[1] | string split ' '
end
