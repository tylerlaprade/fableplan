#!/usr/bin/env bats

setup_file() {
  case ${FABLEPLAN_SHELL:-} in
    bash|zsh|fish) command -v "$FABLEPLAN_SHELL" >/dev/null || { echo "$FABLEPLAN_SHELL is not installed" >&2; return 1; } ;;
    *) echo "Set FABLEPLAN_SHELL to bash, zsh, or fish" >&2; return 1 ;;
  esac
}

setup() {
  PATH="${BATS_TEST_DIRNAME:?}/bin:$PATH"
  FAKE_CLAUDE_LAUNCH="${BATS_TEST_TMPDIR:?}/launch.json"
  export PATH FAKE_CLAUDE_LAUNCH
  unset ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL FAKE_USER_SETTINGS FAKE_CLAUDE_UNRESOLVED
}

fableplan() {
  case $FABLEPLAN_SHELL in
    fish) fish --no-config "$BATS_TEST_DIRNAME/run.fish" "$@" ;;
    zsh) zsh -f "$BATS_TEST_DIRNAME/run.sh" "$@" ;;
    bash) bash "$BATS_TEST_DIRNAME/run.sh" "$@" ;;
  esac
}

launched() {
  local actual
  actual=$(jq -r "$1" "$FAKE_CLAUDE_LAUNCH")
  [[ $actual == "$2" ]]
}

launched_setting() {
  launched ".[index(\"--settings\") + 1] | fromjson | $1" "$2"
}

launched_passthrough() {
  launched '.[index("--settings") + 2:] | tojson' "$1"
}

refused() {
  [[ $status -ne 0 ]]
  [[ $output == *"$1"* ]]
  [[ ! -e $FAKE_CLAUDE_LAUNCH ]]
}

@test "launches opusplan in plan mode on the latest Fable and Opus" {
  run fableplan -p "hello world"
  [[ $status -eq 0 ]]
  [[ -z $output ]]
  launched '.[0:5] | tojson' '["--model","opusplan","--permission-mode","plan","--settings"]'
  launched_setting .env.ANTHROPIC_DEFAULT_OPUS_MODEL claude-fable-5-1
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-5-5
  launched_setting .env.CLAUDE_CODE_SUBAGENT_MODEL inherit
  launched_setting .env.ANTHROPIC_CUSTOM_MODEL_OPTION opusplan
  launched_setting .env.ANTHROPIC_CUSTOM_MODEL_OPTION_NAME "Fable Plan"
  launched_passthrough '["-p","hello world"]'
}

@test "merges every --settings into a single one, later values winning" {
  printf '%s' '{"env":{"FROM":"file"},"permissions":{"allow":["Bash(ls)"]}}' >"$BATS_TEST_TMPDIR/settings.json"
  run fableplan --settings "$BATS_TEST_TMPDIR/settings.json" --settings '{"env":{"FROM":"flag"}}' -c
  [[ $status -eq 0 ]]
  launched '[.[] | select(. == "--settings")] | length' 1
  launched_setting .env.FROM flag
  launched_setting '.permissions.allow[0]' 'Bash(ls)'
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-5-5
  launched_passthrough '["-c"]'
}

@test "accepts --settings=VALUE" {
  run fableplan '--settings={"includeGitInstructions":false}'
  [[ $status -eq 0 ]]
  launched_setting .includeGitInstructions false
}

@test "plans on an older Fable pinned in --settings, with a warning" {
  run fableplan --settings '{"env":{"ANTHROPIC_DEFAULT_FABLE_MODEL":"claude-fable-5"}}'
  [[ $status -eq 0 ]]
  [[ $output == *"using claude-fable-5 from ANTHROPIC_DEFAULT_FABLE_MODEL instead of the latest claude-fable-5-1"* ]]
  launched_setting .env.ANTHROPIC_DEFAULT_OPUS_MODEL claude-fable-5
}

@test "executes on an older Opus pinned in the shell, with a warning" {
  ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-8 run fableplan
  [[ $status -eq 0 ]]
  [[ $output == *"using claude-opus-4-8 from ANTHROPIC_DEFAULT_OPUS_MODEL instead of the latest claude-opus-5-5"* ]]
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-4-8
}

@test "executes on an older Opus pinned in a settings file" {
  FAKE_USER_SETTINGS='{"env":{"ANTHROPIC_DEFAULT_OPUS_MODEL":"claude-opus-4-8"}}' run fableplan
  [[ $status -eq 0 ]]
  [[ $output == *"using claude-opus-4-8"* ]]
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-4-8
}

@test "keeps the [1m] tag on a pin" {
  run fableplan --settings '{"env":{"ANTHROPIC_DEFAULT_OPUS_MODEL":"claude-opus-4-6[1m]"}}'
  [[ $status -eq 0 ]]
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL 'claude-opus-4-6[1m]'
}

@test "stays silent when a pin names the latest model" {
  ANTHROPIC_DEFAULT_FABLE_MODEL=claude-fable-5-1 run fableplan
  [[ $status -eq 0 ]]
  [[ -z $output ]]
}

@test "ignores a cross-family pin inherited from a parent fableplan" {
  ANTHROPIC_DEFAULT_OPUS_MODEL=claude-fable-5-1 run fableplan
  [[ $status -eq 0 ]]
  [[ -z $output ]]
  launched_setting .env.ANTHROPIC_DEFAULT_SONNET_MODEL claude-opus-5-5
}

@test "refuses a cross-family pin in --settings" {
  run fableplan --settings '{"env":{"ANTHROPIC_DEFAULT_OPUS_MODEL":"claude-fable-5"}}'
  refused "outside the Opus family"
}

@test "refuses any Sonnet pin in --settings" {
  run fableplan --settings '{"env":{"ANTHROPIC_DEFAULT_SONNET_MODEL":"claude-opus-5"}}'
  refused "execution runs in the sonnet slot"
}

@test "refuses --model in both forms" {
  run fableplan --model opusplan
  refused "--model would replace opusplan"
  run fableplan --model=sonnet
  refused "--model would replace opusplan"
}

@test "refuses unreadable --settings" {
  run fableplan --settings '{not json'
  refused "not a valid JSON object"
  run fableplan --settings "$BATS_TEST_TMPDIR/missing.json"
  refused "settings file not found"
  run fableplan --settings
  refused "--settings needs a value"
}

@test "lets the caller's picker entry replace Fable Plan" {
  run fableplan --settings '{"env":{"ANTHROPIC_CUSTOM_MODEL_OPTION":"mine"}}'
  [[ $status -eq 0 ]]
  launched_setting .env.ANTHROPIC_CUSTOM_MODEL_OPTION mine
  launched_setting .env.ANTHROPIC_CUSTOM_MODEL_OPTION_NAME null
}

@test "passes everything after -- through untouched" {
  run fableplan -- --model sonnet
  [[ $status -eq 0 ]]
  launched_passthrough '["--","--model","sonnet"]'
}

@test "stops when Claude Code cannot resolve an alias" {
  FAKE_CLAUDE_UNRESOLVED=opus run fableplan
  refused "did not resolve the \`opus\` model alias"
}
