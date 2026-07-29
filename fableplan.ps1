# fableplan — Fable 5 plans, Opus 5 executes.
# Mechanism, economics, and caveats: see README.md in this directory.
#
# PowerShell port of fableplan.sh. Same five variables, same values.
#
# The POSIX version wraps the exports in a subshell so they never outlive the
# call. PowerShell has no subshell: $env: assignments hit the current process.
# The equivalent guarantee is built here by hand — every variable is captured
# before it is set and restored in a finally block, including the "it was not
# set at all" case, so an interrupted or failed run cannot leave a remapped
# alias behind in your session. That distinction matters: a leaked
# ANTHROPIC_DEFAULT_SONNET_MODEL silently sends every later `sonnet` request,
# subagents included, to Opus 5.

function fableplan {
    # Full model names only — these variables reject the `fable`/`opus`/`best`
    # aliases that track the latest release, so each one is pinned by hand.
    $wanted = [ordered]@{
        ANTHROPIC_DEFAULT_OPUS_MODEL   = 'claude-fable-5'
        ANTHROPIC_DEFAULT_SONNET_MODEL = 'claude-opus-5'
        # Adds an honestly-labeled "Fable Plan" entry to the /model picker
        # (the built-in entry for this mode says "Opus Plan").
        ANTHROPIC_CUSTOM_MODEL_OPTION             = 'opusplan'
        ANTHROPIC_CUSTOM_MODEL_OPTION_NAME        = 'Fable Plan'
        ANTHROPIC_CUSTOM_MODEL_OPTION_DESCRIPTION = 'Fable 5 in plan mode, Opus 5 otherwise'
    }

    $saved = @{}
    foreach ($name in $wanted.Keys) {
        # $null means "was not set"; an empty string is a real value and is
        # restored as one.
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    }

    try {
        foreach ($name in $wanted.Keys) {
            [Environment]::SetEnvironmentVariable($name, $wanted[$name], 'Process')
        }
        claude --model opusplan --permission-mode plan @args
    }
    finally {
        foreach ($name in $wanted.Keys) {
            [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process')
        }
    }
}
