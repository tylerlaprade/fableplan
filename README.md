# fableplan

**Fable plans, Opus executes.** Fableplan adds a **Fable Plan** row to Claude Code's `/model` picker. Pick it and Claude Code talks to Fable 5.1 while the session is in plan mode and to Opus 5 in every other mode.

<img width="1335" height="299" alt="Fable Plan in Claude Code" src="https://github.com/user-attachments/assets/116e7728-4633-4fcc-a2a5-af2a8f316ac2" />

```sh
fableplan                  # start a new session in plan mode
fableplan -c               # continue the latest session in plan mode
fableplan --resume <id>    # resume a session by ID in plan mode
```

The wrapper selects the row for you. Inside the session, `/model` still works: switch to plain Opus or Sonnet and back to Fable Plan whenever you like.

## Install

Requires a Claude Code build that honours the `modelPicker` setting and `BUN_OPTIONS`; tested with 2.1.266. Needs `jq` on `PATH` for the hook.

**bash and zsh** — clone and source it:

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
echo 'source ~/.fableplan/fableplan.sh' >> ~/.zshrc   # or ~/.bashrc
```

**zsh plugin managers** — these autoload `fableplan.plugin.zsh`:

```zsh
antigen bundle tylerlaprade/fableplan   # Antigen
zinit light tylerlaprade/fableplan      # Zinit or Zgenom
```

For Oh My Zsh, clone the repository into `${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fableplan`, then add `fableplan` to `plugins=(...)`.

**fish** — link the autoloaded function:

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
ln -s ~/.fableplan/fableplan.fish ~/.config/fish/functions/fableplan.fish
```

**Uninstall:** remove the source line or plugin entry, then delete `~/.fableplan`. If `/model` last saved Fable Plan, pick another model first, or `claude` will start with a model id it no longer understands.

## How it works

Claude Code has one mode-dependent model, [`opusplan`](https://code.claude.com/docs/en/model-config#opusplan-model-setting), and its split is fixed in the binary: the `opus` tier in plan mode, the `sonnet` tier otherwise. Earlier versions of fableplan pointed those tiers elsewhere with `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL`. That worked, but for the rest of the session `opus` meant Fable and `sonnet` meant Opus, for subagents and fallback chains too.

This version leaves the tiers alone and adds a model of its own. Three pieces:

1. **A picker row.** `fableplan.settings.json` adds a `modelPicker` row whose model id is `fableplan`. Claude Code does not know that id, so `behavesAs: claude-opus-5` tells it which prompt profile and context window to assume. The id itself goes into every API request unchanged.
2. **A fetch preload.** `fableplan.js` is loaded into the `claude` binary through `BUN_OPTIONS=--preload` before its bundle runs. It wraps `fetch`, and on requests to `/v1/messages` that carry `model: "fableplan"` it writes `claude-fable-5-1` in plan mode and `claude-opus-5` otherwise. Every other request passes through untouched.
3. **A one-line hook.** The preload has no view of Claude Code's state, but hooks do: `UserPromptSubmit`, `PreToolUse` and `PostToolUse` all receive `permission_mode`. The hook in `fableplan.settings.json` writes it to `$XDG_RUNTIME_DIR/claude-mode.<pid>` (falling back to `$TMPDIR`, then `/tmp`). The preload reads that file on every request and deletes it on exit.

| Permission mode | Model sent |
|---|---|
| `plan` | `claude-fable-5-1` |
| anything else | `claude-opus-5` |

`fableplan()` sets `BUN_OPTIONS`, passes `--settings fableplan.settings.json`, and starts with `--model fableplan --permission-mode plan`. Everything else is a normal `claude` invocation, so your own `claude` wrapper still applies.

Compared with the alias remap:

- `opus` means Opus. `/model opus`, `model: opus` in an agent definition, and fallback chains keep their meaning.
- Fable Plan is a real picker entry. Choose it, leave it, and come back mid-session. The startup banner says Fable Plan as well.
- Subagents need no special handling. Agents that name a model get that model; agents that inherit get `fableplan` and follow the same split.

## Caveats

- **Resume with `fableplan`, not plain `claude`.** Choosing Fable Plan saves `fableplan` as your default model in `~/.claude/settings.json`. A plain `claude` session has no preload, sends that id to the API as-is, and fails. Run through `fableplan`, or pick another model in `/model`.
- **The mode can lag one request.** Hooks refresh the mode file on each prompt and tool call. After you approve a plan, the request that produces the first tool call may still go to Fable; from the next tool call on it is Opus. A Shift+Tab mode change applies at the next prompt.
- **`BUN_OPTIONS` is not a Claude Code feature.** The binary is compiled with Bun, and Bun reads `BUN_OPTIONS` before the bundle starts. A future build could stop honouring it, or change the request shape the preload looks for. Recheck after major upgrades, and delete this if Claude Code ever ships a fableplan of its own.
- **Model ids are pinned.** `PLAN_MODEL` and `BUILD_MODEL` sit at the top of `fableplan.js`. The API takes full ids only, so each new Fable or Opus release needs a version update.
- **Status lines see `fableplan`.** The status line JSON reports the row id, not the model of the moment. A status line that wants the live model can read the same mode file; the pid is `$CLAUDE_PID` when set, otherwise the nearest `claude` ancestor.
- **Context window follows `behavesAs`.** Claude Code assumes the window it has on record for `claude-opus-5` and auto-compacts on that, in both modes.
- **Refusal fallbacks are untested** with the preload in place.

<details>
<summary><b>Economics</b>: about $14 instead of $25 for an all-Fable session</summary>

Prices per million input/output tokens: Fable $10/$50; Opus 5 $5/$25. Prompt caches are model-specific and expire after five minutes. Cache writes cost 1.25 times the input price; reads cost 0.1 times the input price. The estimate assumes a 100K-token plan, more than five minutes of review, about 50 execution turns growing the context to 250K, 8M cache-read tokens, and 50K output tokens.

- Switching to Opus writes the plan context into Opus's cache, about $0.63 per 100K tokens. The lower cache-read price recovers that cost in about ten turns.
- If review takes more than five minutes, the Fable cache has already expired. Rewriting the context on Opus costs half as much as rewriting it on Fable.
- Returning to plan mode writes the full context to Fable's cache, costing up to about $2.50.

</details>

<details>
<summary><b>Verify</b> the routing</summary>

`modelUsage` in the JSON output is keyed by the requested id, so read the model the API answered with instead:

```sh
served='[.[] | select(.type=="assistant") | .message.model] | unique'
# Plan: expect ["claude-fable-5-1"].
zsh -ic 'fableplan -p --output-format json "Reply OK"' | jq "$served"
# Execution: expect ["claude-opus-5"].
zsh -ic 'fableplan -p --permission-mode acceptEdits --output-format json "Reply OK"' | jq "$served"
```

In an interactive session the same field is in the transcript under `~/.claude/projects/`.

</details>

## License

[GPL-3.0](LICENSE).
