# fableplan — Fable 5.1 plans, Opus 5 executes.
# Mechanism and caveats: see README.md in this directory.
#
# set -lx makes each var function-local and exported: it reaches `claude`
# (including a wrapper function) and vanishes when fableplan returns —
# fish's native equivalent of the subshell in fableplan.sh.
function fableplan --description "Claude Code: Fable 5.1 plans, Opus 5 executes"
    if not command -q jq
        echo "fableplan: jq is required (the mode hook uses it) but is not on PATH" >&2
        return 1
    end
    # path resolve follows the symlink from ~/.config/fish/functions back to
    # the clone, where the preload, settings and hook live. The hook in
    # fableplan.settings.json finds its script through FABLEPLAN_DIR.
    set -lx FABLEPLAN_DIR (path resolve (status filename) | path dirname)
    # Loads fableplan.js into the claude binary before its bundle runs. Bun
    # splits BUN_OPTIONS on whitespace and ignores quotes, so whitespace and
    # backslashes in the path are backslash-escaped. An existing BUN_OPTIONS
    # value is kept.
    set -l preload (string replace -ra '([\s\\\\])' '\\\\$1' -- "$FABLEPLAN_DIR/fableplan.js")
    if set -q BUN_OPTIONS
        set -lx BUN_OPTIONS "$BUN_OPTIONS --preload $preload"
    else
        set -lx BUN_OPTIONS "--preload $preload"
    end
    # Adds the Fable Plan picker row and the hook that records the permission
    # mode; --model selects the row for this session.
    claude --settings "$FABLEPLAN_DIR/fableplan.settings.json" \
        --model fableplan --permission-mode plan $argv
end
