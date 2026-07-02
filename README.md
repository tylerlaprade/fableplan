# fableplan

**Fable plans, Opus executes** — the old `opusplan` idea bumped up a model tier.

<img width="1335" height="299" alt="image" src="https://github.com/user-attachments/assets/116e7728-4633-4fcc-a2a5-af2a8f316ac2" />

```sh
fableplan                  # new session
fableplan -c               # continue — always resume fableplan sessions with
fableplan --resume <id>    #   fableplan, never plain `claude` (see Caveats)
```

## Install

Nothing runs at install time — you add one `source` line (or a plugin-manager
entry) and it takes effect in new shells.

**Manual (bash or zsh):**

```sh
git clone https://github.com/tylerlaprade/fableplan ~/.fableplan
echo 'source ~/.fableplan/fableplan.sh' >> ~/.zshrc   # or ~/.bashrc
```

Open a new shell, or `source ~/.fableplan/fableplan.sh` to use it right away.

**Zsh plugin managers** (they load `fableplan.plugin.zsh` automatically):

```zsh
antigen bundle tylerlaprade/fableplan            # antigen
zinit light tylerlaprade/fableplan               # zinit / zgenom
```

For oh-my-zsh, clone into the custom plugins dir and add `fableplan` to `plugins`:

```zsh
git clone https://github.com/tylerlaprade/fableplan \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fableplan
# then in ~/.zshrc:  plugins=(… fableplan)
```

**Fish:** unsupported for now — the function relies on POSIX per-command env
prefixes. PRs welcome.

## Uninstall

Remove the `source` line (or the plugin-manager entry) you added, then:

```sh
rm -rf ~/.fableplan
```

## How it works

Claude Code's `opusplan` model setting is the only built-in mechanism that
switches models at the plan-mode boundary. Per the
[model-config docs](https://code.claude.com/docs/en/model-config), `opusplan`
uses `opus` in plan mode and `sonnet` otherwise; `ANTHROPIC_DEFAULT_OPUS_MODEL`
is "the model to use for `opus`, or for `opusplan` when Plan Mode is active" and
`ANTHROPIC_DEFAULT_SONNET_MODEL` the model to use "when Plan Mode is not active".
The effective model resolves **per request**:

```
setting == opusplan  &&  permissionMode == plan  &&  context <= 200K
    -> resolve the "opus" alias   (ANTHROPIC_DEFAULT_OPUS_MODEL first)
otherwise
    -> resolve the "sonnet" alias (ANTHROPIC_DEFAULT_SONNET_MODEL first)
```

The alias resolution is documented above; the ≤200K-context guard is observed
in v2.1.198 and not documented.

`fableplan()` sets those two env vars for the invocation only:

| | alias | resolves to |
|---|---|---|
| plan mode | `opus` | `claude-fable-5` |
| execution | `sonnet` | `claude-opus-4-8` |

There is no hook, setting, or plan-mode model key that does this any other
way; hooks cannot change models and none fire on mode changes.

## Economics (why the switch is worth it)

Prices per MTok: Fable $10/$50 · Opus 4.8 $5/$25. Prompt caches are
**per-model**, 5-min TTL; writes 1.25× input, reads 0.1×.

Reference session (plan to ~100K context, >5 min review, ~50 execution turns
to ~250K, ~8M cache reads, ~50K output):

| | total | vs all-Fable |
|---|---|---|
| all-Fable | ~$25 | — |
| fableplan | ~$14 | −43% |

- The plan→exec switch costs one uncached re-read of the plan-phase context
  on Opus (~$0.63 per 100K) — recovered within ~10 execution turns.
- If plan review takes >5 min (usual), the Fable cache expired anyway, and
  Opus's fresh write ($6.25/M) is half of Fable's re-write ($12.50/M): the
  switch is then strictly cheaper than staying.
- Re-entering plan mode mid-session ≤200K context pays a Fable cache write on
  the full context (up to ~$2.50 at 200K).

## Caveats

- **Resume with `fableplan`, never plain `claude`**: the env remap lives only
  in the fableplan invocation. `claude -c` / `claude --resume` on a
  fableplan-created session restores the `opusplan` setting but not the remap
  — plan mode silently becomes real Opus 4.8 and execution becomes Sonnet 5,
  with no error.
- **Alias remap inside fableplan sessions**: `opus` *means* Fable and
  `sonnet` *means* Opus 4.8 — in the `/model` picker (labels don't update on
  the direct API), in subagent `model: opus/sonnet` frontmatter, and in
  fallback chains. A tab you forgot was fableplan behaves differently from a
  plain one. `haiku` and background traffic are untouched.
- **200K guard**: above 200K conversation tokens, plan mode silently stops
  upgrading — you plan on Opus 4.8 with no UI indication. For a Fable-quality
  replan in a deep session, start a fresh session from the plan file instead.
- **Safety fallback on managed platforms**: Fable's automatic cyber/bio safety
  fallback resolves its target through `ANTHROPIC_DEFAULT_OPUS_MODEL`, which the
  docs' [automatic model fallback](https://code.claude.com/docs/en/model-config)
  section says "must resolve to an Opus model". Under this remap that var points
  at `claude-fable-5`, which isn't one — so on Bedrock/Vertex/Foundry a flagged
  request ends in a refusal rather than a graceful reroute. Direct-API
  resolution of this fallback is undocumented; treat it as unverified there.
- `opusplan` semantics belong to Anthropic and have changed across releases;
  re-check `code.claude.com/docs/en/model-config` after major updates.

## Verify

```sh
# execution half — expect claude-opus-4-8
zsh -ic 'fableplan -p --output-format json "Reply OK"' | jq '.modelUsage | keys'

# plan half — expect claude-fable-5[1m] (the [1m] suffix is added by Claude
# Code's extended-context handling and stripped before the API call)
zsh -ic 'fableplan -p --permission-mode plan --output-format json "Reply OK"' | jq '.modelUsage | keys'
```

## License

[GPL-3.0](LICENSE).
