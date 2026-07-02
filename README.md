# fableplan

**Fable plans, Opus executes** — the old `opusplan` idea bumped up a model tier.

<img width="1335" height="299" alt="image" src="https://github.com/user-attachments/assets/116e7728-4633-4fcc-a2a5-af2a8f316ac2" />

```sh
fableplan                  # new session
fableplan -c               # continue — always resume fableplan sessions with
fableplan --resume <id>    #   fableplan, never plain `claude` (see Caveats)
```

## Install

**bash / zsh** — clone and source it:

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
echo 'source ~/.fableplan/fableplan.sh' >> ~/.zshrc   # or ~/.bashrc
```

**zsh plugin managers** (they autoload `fableplan.plugin.zsh`):

```zsh
antigen bundle tylerlaprade/fableplan            # antigen
zinit light tylerlaprade/fableplan               # zinit / zgenom
# oh-my-zsh: clone into ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fableplan, add `fableplan` to plugins=()
```

**fish** — symlink the autoloaded function:

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
ln -s ~/.fableplan/fableplan.fish ~/.config/fish/functions/fableplan.fish
```

**Uninstall:** remove the line/entry you added, then `rm -rf ~/.fableplan`.

## How it works

`opusplan` is Claude Code's only built-in model switch at the plan-mode boundary. Per the [model-config docs](https://code.claude.com/docs/en/model-config) it uses the `opus` alias in plan mode and `sonnet` otherwise, each overridable by an env var. `fableplan()` sets both, scoped to the one invocation:

| mode | alias (env var) | fableplan points it at |
|---|---|---|
| plan | `opus` (`ANTHROPIC_DEFAULT_OPUS_MODEL`) | `claude-fable-5` |
| execution | `sonnet` (`ANTHROPIC_DEFAULT_SONNET_MODEL`) | `claude-opus-4-8` |

No hook or setting can do this instead — hooks can't change models and none fire on mode changes. (Plan-mode upgrade also has a ≤200K-context guard, observed in v2.1.198, undocumented.)

## Caveats

- **Resume with `fableplan`, never plain `claude`.** The remap lives only in the fableplan invocation. `claude -c`/`--resume` on a fableplan session keeps the `opusplan` setting but not the remap — plan silently becomes real Opus 4.8, execution becomes Sonnet 5, no error.
- **Inside a fableplan session, `opus` means Fable and `sonnet` means Opus 4.8** — in subagent `model:` frontmatter and fallback chains. The `/model` picker is honest (a **Fable Plan** entry marks the mode), but the startup banner still says "Opus Plan" (hardcoded in Claude Code).
- **200K guard:** above 200K tokens, plan mode silently stops upgrading — you plan on Opus 4.8 with no indication. Start a fresh session from the plan file for a Fable-quality replan.
- **Managed platforms:** Fable's cyber/bio safety fallback resolves through `ANTHROPIC_DEFAULT_OPUS_MODEL`, which the [docs](https://code.claude.com/docs/en/model-config) say "must resolve to an Opus model." Under the remap it points at `claude-fable-5`, so on Bedrock/Vertex/Foundry a flagged request refuses instead of rerouting. Direct-API behavior here is undocumented.
- `opusplan` semantics are Anthropic's and change across releases — re-check the docs after major updates.

<details>
<summary><b>Economics</b> — ~$14 vs ~$25 all-Fable (−43%)</summary>

Prices per MTok: Fable $10/$50 · Opus 4.8 $5/$25. Caches are per-model, 5-min TTL; writes 1.25× input, reads 0.1×. Reference session = plan to ~100K, >5 min review, ~50 exec turns to ~250K, ~8M cache reads, ~50K output.

- The plan→exec switch costs one uncached re-read of plan context on Opus (~$0.63/100K) — recovered within ~10 turns.
- If review takes >5 min (usual), the Fable cache expired anyway; Opus's fresh write ($6.25/M) is half of Fable's re-write ($12.50/M), so switching is strictly cheaper than staying.
- Re-entering plan mode ≤200K pays a Fable cache write on the full context (up to ~$2.50 at 200K).

</details>

<details>
<summary><b>Verify</b> the routing</summary>

```sh
# execution half — expect claude-opus-4-8
zsh -ic 'fableplan -p --output-format json "Reply OK"' | jq '.modelUsage | keys'
# plan half — expect claude-fable-5[1m]  ([1m] = extended-context tag, stripped before the API call)
zsh -ic 'fableplan -p --permission-mode plan --output-format json "Reply OK"' | jq '.modelUsage | keys'
```

</details>

## License

[GPL-3.0](LICENSE).
