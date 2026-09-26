# fableplan

**Fable plans, Opus executes.** Fableplan configures both parts of Claude Code's built-in `opusplan` mode.

<img width="1335" height="299" alt="Fable Plan in Claude Code" src="https://github.com/user-attachments/assets/116e7728-4633-4fcc-a2a5-af2a8f316ac2" />

```sh
fableplan                  # start a new session in plan mode
fableplan -c               # continue the latest session in plan mode
fableplan --resume <id>    # resume a session by ID in plan mode
```

## Install

Requires Claude Code 2.1.280 or later and `jq` 1.7 or later.

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

**fish** — link the autoloaded function. It resolves models through `fableplan.sh` beside it, so it also needs `bash`:

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
ln -s ~/.fableplan/fableplan.fish ~/.config/fish/functions/fableplan.fish
```

**Uninstall:** remove the source line or plugin entry, then delete `~/.fableplan`.

## How it works

Claude Code's [`opusplan` mode](https://code.claude.com/docs/en/model-config#opusplan-model-setting) uses the `opus` alias in plan mode and `sonnet` during execution. `fableplan()` remaps both aliases for one invocation by passing the variables in `--settings`, which outranks the `env` block of your user, project, and local settings:

| Mode | Alias and environment variable | Fableplan target |
|---|---|---|
| Plan | `opus` (`ANTHROPIC_DEFAULT_OPUS_MODEL`) | what `fable` resolves to, now `claude-fable-5-1` |
| Execution | `sonnet` (`ANTHROPIC_DEFAULT_SONNET_MODEL`) | what `opus` resolves to, now `claude-opus-5-5` |

These environment variables require full model names and reject aliases such as `fable` and `opus`. So each launch first asks the installed Claude Code what those two aliases resolve to, through one bare, hook-free Claude Code process that makes no API call: it reports the `fable` model, switches to `opus`, and reports again. That adds about two thirds of a second on an idle machine, and the same replies report any pin, so a pinned launch costs no more. A new Fable or Opus arrives with the Claude Code update that makes it the alias target. An `ANTHROPIC_DEFAULT_FABLE_MODEL` or `ANTHROPIC_DEFAULT_OPUS_MODEL` pin from your shell or settings still wins with a warning, so pinning `claude-fable-5` plans on Fable 5. A pin outside its family is ignored, so an Opus pin that a parent `fableplan` session pointed at Fable falls back to the latest Opus. If Claude Code cannot resolve an alias, `fableplan` stops with an error instead of launching.

Fableplan also takes over your own `--settings` and `--model` flags, because Claude Code keeps only the last of each and would silently drop the remap. It merges every `--settings`, whether a JSON string or a file, into its own. An `ANTHROPIC_DEFAULT_FABLE_MODEL` naming an older Fable, or an `ANTHROPIC_DEFAULT_OPUS_MODEL` naming an older Opus, replaces the latest one with a warning. A pin outside its family, or any `ANTHROPIC_DEFAULT_SONNET_MODEL`, stops the launch, since execution runs in the `sonnet` slot. `--model` stops the launch too. Every Fable and every Opus since 4.7 already runs with 1M context; to give an older pin 1M context, append `[1m]` to the pinned name. If you set `ANTHROPIC_CUSTOM_MODEL_OPTION`, your picker entry replaces Fable Plan. Managed settings still outrank everything Fableplan passes.

Hooks cannot replace the remap: they cannot change models, and none run when the mode changes.

The wrapper passes `--permission-mode plan`, so new and resumed sessions start in plan mode. You can leave plan mode after startup.

It also sets `CLAUDE_CODE_SUBAGENT_MODEL=inherit`. Built-in subagents follow the current model, while agents that choose a model keep their choice. The remap still applies to aliases: `opus` means the plan model and `sonnet` means the execution model.

## Caveats

- **Resume with `fableplan`, not plain `claude`.** The remap lasts only for one invocation. Resuming with plain `claude` restores `opusplan` without the remap, so planning uses your `opus` model and execution uses your `sonnet` model.
- **Aliases have new meanings throughout the session.** This includes subagents and fallback chains. The `/model` picker shows **Fable Plan**, but Claude Code's startup banner still says **Opus Plan**.
- **Open a new shell after updating.** A shell keeps the `fableplan` it loaded at startup, so tabs opened before an update still run the old version. Open a new tab or source the file again.
- **Planning stops switching to Fable above 200K tokens.** Claude Code 2.1.282 keeps planning on the execution model without a notice. Start a fresh session from the plan file for a Fable replan.
- **Safety fallbacks differ by provider.** On the Anthropic API, flagged Fable 5.1 and Opus 5.5 requests switch to Opus 5 for biology or Opus 4.8 for cybersecurity. On Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry, cybersecurity-flagged requests re-run on the model in `ANTHROPIC_DEFAULT_OPUS_MODEL`. Fableplan points that variable at Fable, so those requests refuse instead of switching. ([docs](https://code.claude.com/docs/en/model-config#automatic-model-fallback))
- Claude Code can change `opusplan` and fallback behavior. Recheck both after major upgrades.

<details>
<summary><b>Economics</b>: execution costs about $3.85 instead of $7.63 on Fable</summary>

Prices per million tokens (input / output / 5-minute cache write / cache read): Fable 5.1 $10 / $50 / $12.50 / $0.25; Opus 5.5 $4 / $20 / $5 / $0.20. Prompt caches are model-specific and expire after five minutes. Planning costs the same either way, so the comparison covers execution. The estimate assumes a 100K-token plan, more than five minutes of review, about 50 execution turns growing the context to 250K, 8M cache-read tokens, and 50K output tokens.

- Nearly all of the savings come from output and cache writes, which cost 2.5 times less on Opus 5.5. Cache reads cost only 20% less.
- Switching to Opus writes the plan context into Opus's cache, about $0.50 per 100K tokens. The cheaper output and writes recover that in about ten turns at this scenario's per-turn rate.
- If review takes more than five minutes, the Fable cache has already expired. Rewriting the context on Opus costs 2.5 times less than rewriting it on Fable.
- Returning to plan mode at or below 200K tokens writes the full context to Fable's cache, costing up to about $2.50.

</details>

<details>
<summary><b>Verify</b> the routing</summary>

```sh
# Plan: expect the model `fable` resolves to, with the [1m] tag.
# Claude Code strips the [1m] context tag before the API call.
zsh -ic 'fableplan -p --output-format json "Reply OK"' | jq '.modelUsage | keys'
# Execution: expect the model `opus` resolves to.
zsh -ic 'fableplan -p --permission-mode acceptEdits --output-format json "Reply OK"' | jq '.modelUsage | keys'
```

</details>

## Development

CI runs ShellCheck with every rule enabled, checks the fish files with `fish --no-execute` and `fish_indent`, and runs the bats suite once per shell against a stand-in `claude` in `tests/bin`, so no test reaches the API.

```sh
shellcheck fableplan.sh tests/bin/claude tests/run.sh tests/fableplan.bats
FABLEPLAN_SHELL=bash bats tests   # also zsh, or fish where it is installed
```

## License

[GPL-3.0](LICENSE).
