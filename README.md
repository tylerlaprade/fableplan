# fableplan

**Fable plans, Opus executes.** Fableplan configures both parts of Claude Code's built-in `opusplan` mode.

<img width="1335" height="299" alt="Fable Plan in Claude Code" src="https://github.com/user-attachments/assets/116e7728-4633-4fcc-a2a5-af2a8f316ac2" />

```sh
fableplan                  # start a new session in plan mode
fableplan -c               # continue the latest session in plan mode
fableplan --resume <id>    # resume a session by ID in plan mode
```

## Install

Requires Claude Code 2.1.219 or later, which added Opus 5. Older versions reject the execution model at startup.

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

**Uninstall:** remove the source line or plugin entry, then delete `~/.fableplan`.

## How it works

Claude Code's [`opusplan` mode](https://code.claude.com/docs/en/model-config#opusplan-model-setting) uses the `opus` alias in plan mode and `sonnet` during execution. `fableplan()` remaps both aliases for one invocation:

| Mode | Alias and environment variable | Fableplan target |
|---|---|---|
| Plan | `opus` (`ANTHROPIC_DEFAULT_OPUS_MODEL`) | `claude-fable-5` |
| Execution | `sonnet` (`ANTHROPIC_DEFAULT_SONNET_MODEL`) | `claude-opus-5` |

These environment variables require full model names. Tracking aliases such as `fable`, `opus`, and `best` do not work here, so each new Fable or Opus release requires a version update.

Hooks cannot replace the remap: they cannot change models, and none run when the mode changes.

The wrapper passes `--permission-mode plan`, so new and resumed sessions start in plan mode. You can leave plan mode after startup.

It also sets `CLAUDE_CODE_SUBAGENT_MODEL=inherit`. Built-in subagents follow the current model, while agents that choose a model keep their choice. The remap still applies to aliases: `opus` means Fable and `sonnet` means Opus.

## Caveats

- **Resume with `fableplan`, not plain `claude`.** The remap lasts only for one invocation. Resuming with plain `claude` restores `opusplan` without the remap, so planning uses Opus 5 and execution uses Sonnet 5.
- **Aliases have new meanings throughout the session.** This includes subagents and fallback chains. The `/model` picker shows **Fable Plan**, but Claude Code's startup banner still says **Opus Plan**.
- **A user-level subagent setting can override Fableplan.** In Claude Code 2.1.220, `CLAUDE_CODE_SUBAGENT_MODEL` in `settings.json` overrides the wrapper's `inherit` value, contrary to the documented precedence ([upstream bug](https://github.com/anthropics/claude-code/issues/78567#issuecomment-5109786270)). Remove that setting to use mode-aware subagent routing.
- **Planning stops switching to Fable above 200K tokens.** Claude Code 2.1.220 keeps the plan on Opus 5 without a notice. Start a fresh session from the plan file for a Fable replan.
- **Safety fallbacks differ by provider.** On the Anthropic API, flagged Fable requests switch to Opus 5 for biology or Opus 4.8 for cybersecurity. On Amazon Bedrock, Google Cloud's Agent Platform, and Microsoft Foundry, Claude Code resolves the target through `ANTHROPIC_DEFAULT_OPUS_MODEL`. Fableplan points that variable at Fable, so the request refuses instead of switching. ([docs](https://code.claude.com/docs/en/model-config#automatic-model-fallback))
- Claude Code can change `opusplan` and fallback behavior. Recheck both after major upgrades.

<details>
<summary><b>Economics</b>: about $14 instead of $25 for an all-Fable session</summary>

Prices per million input/output tokens: Fable $10/$50; Opus 5 $5/$25. Prompt caches are model-specific and expire after five minutes. Cache writes cost 1.25 times the input price; reads cost 0.1 times the input price. The estimate assumes a 100K-token plan, more than five minutes of review, about 50 execution turns growing the context to 250K, 8M cache-read tokens, and 50K output tokens.

- Switching to Opus writes the plan context into Opus's cache, about $0.63 per 100K tokens. The lower cache-read price recovers that cost in about ten turns.
- If review takes more than five minutes, the Fable cache has already expired. Rewriting the context on Opus costs half as much as rewriting it on Fable.
- Returning to plan mode at or below 200K tokens writes the full context to Fable's cache, costing up to about $2.50.

</details>

<details>
<summary><b>Verify</b> the routing</summary>

```sh
# Plan: expect claude-fable-5[1m].
# Claude Code strips the [1m] context tag before the API call.
zsh -ic 'fableplan -p --output-format json "Reply OK"' | jq '.modelUsage | keys'
# Execution: expect claude-opus-5.
zsh -ic 'fableplan -p --permission-mode acceptEdits --output-format json "Reply OK"' | jq '.modelUsage | keys'
```

</details>

## License

[GPL-3.0](LICENSE).
