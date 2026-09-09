# fableplan — Fable 5.1 plans, Opus 5 executes.
# Mechanism and caveats: see README.md in this directory.
#
# set -lx makes the var function-local and exported: it reaches `claude`
# (including a wrapper function) and vanishes when fableplan returns —
# fish's native equivalent of the subshell in fableplan.sh.
function fableplan --description "Claude Code: Fable 5.1 plans, Opus 5 executes"
    # path resolve follows the symlink from ~/.config/fish/functions back to
    # the clone, where fableplan.js and fableplan.settings.json live.
    set -l dir (path resolve (status filename) | path dirname)
    # Loads fableplan.js into the claude binary before its bundle runs. An
    # existing BUN_OPTIONS value is kept.
    if set -q BUN_OPTIONS
        set -lx BUN_OPTIONS "$BUN_OPTIONS --preload $dir/fableplan.js"
    else
        set -lx BUN_OPTIONS "--preload $dir/fableplan.js"
    end
    # Adds the Fable Plan picker row and the hook that records the permission
    # mode; --model selects the row for this session.
    claude --settings $dir/fableplan.settings.json \
        --model fableplan --permission-mode plan $argv
end
